# 🔐 Guía de Validación DNS para Azure Front Door

## 📋 Contexto
Esta guía te ayuda a configurar el registro TXT necesario para validar tu dominio personalizado en Azure Front Door, específicamente para tu control de DNS personalizado de ARO (Azure Red Hat OpenShift) público.

## 🎯 Información de Validación Requerida

### Datos del Registro TXT
```
Nombre: _dnsauth.apps.arolatamgbb.jaropro.net
Valor: _fdj6t10l86rbkx5eph6v2l0ii5c8sh1
TTL: 3600 segundos (1 hora)
```

### Configuración de tu DNS
- **Zona DNS**: `jaropro.net`
- **Resource Group**: `ROGERPRIVATEGBB`
- **Subdominio a validar**: `apps.arolatamgbb.jaropro.net`

## 🚀 Pasos de Configuración

### Paso 1: Crear el Registro TXT

```bash
az network dns record-set txt add-record \
  --resource-group "ROGERPRIVATEGBB" \
  --zone-name "jaropro.net" \
  --record-set-name "_dnsauth.apps.arolatamgbb" \
  --value "_fdj6t10l86rbkx5eph6v2l0ii5c8sh1"
```

### Paso 2: Verificar la Creación del Registro

```bash
az network dns record-set txt show \
  --resource-group "ROGERPRIVATEGBB" \
  --zone-name "jaropro.net" \
  --name "_dnsauth.apps.arolatamgbb"
```

### Paso 3: Validar DNS Propagación

```bash
# Usando nslookup
nslookup -type=TXT _dnsauth.apps.arolatamgbb.jaropro.net

# Usando dig (alternativa)
dig TXT _dnsauth.apps.arolatamgbb.jaropro.net
```

## 🔍 Alternativa desde Azure Portal

Si prefieres usar la interfaz web:

1. **Navegar a Azure Portal** → Buscar "DNS zones"
2. **Seleccionar**: `jaropro.net` en resource group `ROGERPRIVATEGBB`
3. **Clic en**: "+ Record set"
4. **Configurar**:
   - **Name**: `_dnsauth.apps.arolatamgbb`
   - **Type**: `TXT`
   - **TTL**: `3600`
   - **Value**: `_fdj6t10l86rbkx5eph6v2l0ii5c8sh1`
5. **Guardar**

## ⏰ Tiempo de Propagación

| Servicio | Tiempo Estimado |
|----------|----------------|
| Azure DNS | 1-5 minutos |
| Validación Front Door | 5-15 minutos |
| Total | 10-20 minutos |

## ✅ Verificación de Estado

### Comando para Verificar Validación en Front Door

```bash
az afd custom-domain show \
  --custom-domain-name "app-domain" \
  --profile-name "rooliva-microsoft-com-fd" \
  --resource-group "arogbbwestus3" \
  --query "domainValidationState" -o tsv
```

### Estados Posibles

- **`Pending`**: Validación en proceso
- **`Approved`**: ✅ Validación exitosa
- **`Rejected`**: ❌ Validación fallida

## 🎯 Resultado Final

Una vez completada la validación, tendrás:

- **Endpoint Front Door**: `https://rooliva-endpoint-xxxxx.azurefd.net`
- **Dominio Personalizado**: `https://apps.arolatamgbb.jaropro.net`
- **Aplicación ARO**: Accesible a través de Front Door con SSL/TLS automático

## 🔧 Troubleshooting

### Si la validación falla:

1. **Verificar TTL**: Asegúrate de que el TTL sea 3600 o menos
2. **Verificar propagación DNS**:
   ```bash
   nslookup -type=TXT _dnsauth.apps.arolatamgbb.jaropro.net 8.8.8.8
   ```
3. **Esperar más tiempo**: Algunas veces toma hasta 30 minutos
4. **Verificar valor exacto**: El token debe coincidir exactamente

### Comandos de Limpieza (si es necesario)

```bash
# Eliminar registro TXT si necesitas recrearlo
az network dns record-set txt delete \
  --resource-group "ROGERPRIVATEGBB" \
  --zone-name "jaropro.net" \
  --name "_dnsauth.apps.arolatamgbb" \
  --yes
```

## 📝 Notas Importantes

- **Dominio ARO**: Este proceso valida el dominio personalizado para tu cluster ARO público
- **Seguridad**: Front Door proporcionará certificado SSL/TLS automático una vez validado
- **Performance**: Front Door mejorará la latencia y disponibilidad de tu aplicación ARO
- **Mantenimiento**: El registro TXT puede eliminarse después de la validación exitosa

## 🔗 Enlaces Útiles

- [Documentación Azure Front Door](https://docs.microsoft.com/azure/frontdoor/)
- [Gestión de DNS en Azure](https://docs.microsoft.com/azure/dns/)
- [Troubleshooting Front Door](https://docs.microsoft.com/azure/frontdoor/troubleshoot-issues)

---

**💡 Tip**: Guarda este documento para futuras configuraciones de dominios en tu infraestructura ARO.