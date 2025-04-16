Para extraer (sacar) una imagen que está en el registro de imágenes interno (scopio) de Azure Red Hat OpenShift, puedes seguir estos pasos:

1. Primero, debes autenticarte en el cluster de OpenShift
2. Luego identificar la imagen exacta en el registro interno
3. Finalmente, extraer la imagen usando herramientas como `oc`, `skopeo` o `podman`

Voy a detallarte el proceso paso a paso:

### 1. Autenticarse en el cluster de OpenShift

```bash
# Iniciar sesión en el cluster
oc login --token=<token> --server=<server-url>

# O con usuario y contraseña
oc login -u <usuario> -p <contraseña> --server=<server-url>
```

### 2. Identificar la imagen en el registro interno

```bash
# Listar los proyectos
oc get projects

# Cambiar al proyecto donde está la imagen
oc project <nombre-proyecto>

# Listar las imágenes en el proyecto
oc get imagestreams

# Ver detalles de una imagen específica
oc describe imagestream <nombre-imagestream>
```

### 3. Extraer la imagen usando skopeo

Skopeo es una herramienta perfecta para este propósito, ya que permite copiar imágenes entre diferentes tipos de repositorios:

```bash
# Obtener un token temporal para autenticación
TOKEN=$(oc whoami -t)

# Usar skopeo para copiar la imagen del registro interno a local o a otro registro
skopeo copy \
  docker://image-registry.openshift-image-registry.svc:5000/<proyecto>/<nombre-imagen>:<tag> \
  docker://<destino>/<nombre-imagen>:<tag> \
  --src-tls-verify=false \
  --src-creds="$(oc whoami):${TOKEN}"
```

### 4. Alternativa usando podman

```bash
# Autenticarse en el registro interno
podman login -u kubeadmin -p $(oc whoami -t) image-registry.openshift-image-registry.svc:5000

# Extraer la imagen
podman pull image-registry.openshift-image-registry.svc:5000/<proyecto>/<nombre-imagen>:<tag>

# Si necesitas subir la imagen a otro registro
podman tag image-registry.openshift-image-registry.svc:5000/<proyecto>/<nombre-imagen>:<tag> <nuevo-registro>/<nombre-imagen>:<tag>
podman push <nuevo-registro>/<nombre-imagen>:<tag>
```

### 5. Usar el cliente oc para exponer el registro y facilitar el acceso

```bash
# Exponer la ruta al registro (si no está ya expuesta)
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

# Obtener la ruta al registro
REGISTRY_ROUTE=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')

# Autenticarse en el registro externo
podman login -u kubeadmin -p $(oc whoami -t) $REGISTRY_ROUTE

# Ahora puedes extraer la imagen usando la ruta externa
podman pull $REGISTRY_ROUTE/<proyecto>/<nombre-imagen>:<tag>
```

### Notas importantes:

1. Si necesitas acceder desde fuera del cluster, asegúrate de que el registro tenga una ruta expuesta.

2. Para sistemas de registro con certificados autofirmados, puedes necesitar agregar las opciones `--tls-verify=false` o configurar los certificados adecuadamente.

3. Para copiar a registros externos como Docker Hub o Azure Container Registry, necesitarás también autenticarte en el registro de destino.

4. En entornos más restrictivos, es posible que necesites permisos adicionales para extraer imágenes del registro interno.
