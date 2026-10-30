# Reporte: parte de infraestructura

## Diagrama de arquitectura

![Arquitectura de Concertpass](arquitectura.png)

El cliente (o los scripts de prueba) llama a `ticket-api` por el NodePort 30080 de los nodos. `ticket-api` guarda la reservacion en RDS como `pending` y la encola en SQS FIFO con `MessageGroupId = concert_id`. `ticket-worker` hace polling a la cola, lee la capacidad del concierto en DynamoDB y verifica el inventario en RDS con `FOR UPDATE`. Si hay lugar la marca `booked`, llama a `ticket-checkout` y al recibir 200 la marca `confirmed`; si no, la marca `rejected`.

RDS vive en las subredes privadas de la VPC del cluster y su security group solo acepta el puerto 5432 desde el security group del cluster, asi que solo los pods pueden conectarse. Las credenciales se generan en `setup.sh`, se guardan en Secrets Manager y de ahi se crea el Secret `rds-credentials` que los pods reciben como variables de entorno. El resto de la configuracion (URL de SQS, tabla de DynamoDB, region, URL de checkout) va en el ConfigMap `app-config`. Los nodos usan `LabRole`, que les da permisos para SQS, DynamoDB y Secrets Manager.

## 3. ¿Que beneficios te da usar EKS en este caso?

**Escalar cada servicio por separado.** La carga no es igual en los tres servicios: en un lanzamiento llegan miles de requests a `ticket-api`, pero el trabajo pesado esta en el inventario. Con EKS cada servicio es un Deployment y se escala con un `kubectl scale` sin tocar a los demas. Asi probamos `ticket-worker` con 3 replicas para verificar que el `FOR UPDATE` evita la sobreventa.

**Autorreparacion.** Si un pod de `ticket-worker` se cae a mitad de un mensaje, Kubernetes lo levanta otra vez y el mensaje vuelve a la cola despues del visibility timeout, asi que ninguna reservacion se queda sin procesar.

**Red interna y descubrimiento de servicios.** `ticket-worker` llama a `ticket-checkout` por su nombre de Service (`ticket-checkout-service`) sin saber en que nodo esta ni su IP. `ticket-checkout` no se expone afuera del cluster; solo `ticket-api` tiene NodePort.

**Configuracion separada del codigo.** Las credenciales y URLs llegan como Secret y ConfigMap. La misma imagen de ECR funciona en otro ambiente cambiando solo esos objetos, sin reconstruir.

**Control plane administrado.** AWS opera el API server y etcd con alta disponibilidad; nosotros solo definimos los nodos. Ademas EKS se integra con el resto de AWS: los nodos estan en la misma VPC que RDS, jalan imagenes de ECR y usan un rol de IAM para hablar con SQS, DynamoDB y Secrets Manager sin llaves en el codigo.

**Despliegues sin downtime.** Un cambio de imagen se aplica con rolling update: Kubernetes levanta los pods nuevos antes de bajar los viejos, asi que la API sigue recibiendo reservaciones mientras se actualiza.

**Costo a considerar.** EKS cobra por hora el control plane, mas los nodos EC2 y RDS, aunque no haya trafico. Por eso todo se levanta con `setup.sh` y se destruye con `teardown.sh` al terminar.
