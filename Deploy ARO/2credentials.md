# Service Principal for Azure OpenShift

Before proceeding with the OpenShift installation, you need to create a service principal with administrative rights for your subscription by following the steps outlined in [Azure: Creating a Service Principal][sp-create].

## Step 1: Create a Service Principal

You can create a Service Principal using either:
- The Azure [portal][sp-create-portal]
- The Azure [CLI][sp-create-cli]

### Example using Azure CLI

To create a service principal using Azure CLI, run the following command:

```sh
az ad sp create-for-rbac -n "${PREFIX}arosp" --skip-assignment
```

This creates a service principal named with your desired prefix followed by "arosp" and skips the role assignment step (we'll handle permissions separately in Step 3).

The command will output credentials similar to:
```json
{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "myarosp",
  "name": "http://myarosp",
  "password": "0000-0000-0000-0000-000000000000",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
```

Save this information securely as you'll need it later.

## Step 2: Request Permissions for the Service Principal

In order to properly mint credentials for components in the cluster, your service principal needs to request the following Application [permissions][ad-permissions]:
- `Azure Active Directory Graph -> Application.ReadWrite.OwnedBy`

You can request these permissions using the Azure portal or Azure CLI.

### Requesting Permissions Using the Azure CLI

1. Find the AppId for your service principal:

```console
$ az ad sp list --show-mine -o table
AccountEnabled    AppDisplayName     AppId                                 AppOwnerTenantId                      AppRoleAssignmentRequired    DisplayName        Homepage                   ObjectId                              ObjectType        Odata.type                                    PublisherName    ServicePrincipalType    SignInAudience
----------------  -----------------  ------------------------------------  ------------------------------------  ---------------------------  -----------------  -------------------------  ------------------------------------  ----------------  --------------------------------------------  ---------------  ----------------------  ----------------
...
```

2. Request the `Application.ReadWrite.OwnedBy` permission:

```sh
az ad app permission add --id <AppId> --api 00000002-0000-0000-c000-000000000000 --api-permissions 824c81eb-e3f8-4ee6-8f6d-de7f50d565b7=Role
```

> **NOTE:** `Application.ReadWrite.OwnedBy` permission is granted to the application only after it receives [`Admin Consent`][ad-admin-consent] from the Tenant Administrator.

## Step 3: Attach Administrative Role

The Azure installer creates new identities for the cluster and therefore requires access to create new roles and role assignments. Your service principal will need at least the following roles assigned in your subscription:
- `Contributor`
- `User Access Administrator` [roles][built-in-roles]

You can create role assignments using:
- The Azure [portal][sp-assign-portal] 
- The Azure [CLI][sp-assign-cli]

## Step 4: Acquire Client Secret

You need to save the client secret values to configure your local machine to run the installer. This is your opportunity to collect those values (additional credentials can be added to the service principal in the Azure portal if needed).

You can get the client secret for your service principal using:
- The Azure [portal][sp-creds-portal]
- The Azure [CLI][sp-creds-cli]

## Step 5: Remove Service Principal (Optional)

If you need to remove a Service Principal after it's no longer needed, follow these steps:

1. First, list your Service Principals to identify which one to remove:

```console
$ az ad sp list --show-mine -o table
DisplayName       Id                                    AppId                                 CreatedDateTime
----------------  ------------------------------------  ------------------------------------  --------------------
arctestaro_arosp  5cba4b28-dff9-4f03-a92f-XXXXXXXXXXXX  3794c0a6-b32f-4f99-afd8-AAAAAAAAAAAA  2100-01-28T15:53:24Z
aro-oc9e2sqy      084bce91-7e73-403a-b376-YYYYYYYYYYYY  c32f7e34-a2b6-4f50-b08f-BBBBBBBBBBBB  2100-11-04T06:00:23Z
aro-rwwibcws      28f45b97-27a6-42bf-81eb-WWWWWWWWWWWW  1a82940d-44da-4b0a-88f6-CCCCCCCCCCCC  2100-11-04T06:13:51Z
arosp             1f0fd38c-42bf-42de-89d5-ZZZZZZZZZZZZ  6f6df3d0-cf7b-46dc-b079-DDDDDDDDDDDD  2100-01-28T02:06:29Z
```

2. Delete the Service Principal using its ID:

```sh
az ad sp delete --id 1f0fd38c-42bf-42de-89d5-ZZZZZZZZZZZZ
```

Make sure to replace the ID with the correct one for the Service Principal you want to delete.

<!-- References -->
[ad-admin-consent]: https://docs.microsoft.com/en-us/azure/active-directory/develop/v1-permissions-and-consent#types-of-consent
[ad-permissions]: https://docs.microsoft.com/en-us/azure/active-directory/develop/v1-permissions-and-consent
[sp-create]: https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-create-service-principals
[sp-create-portal]: https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-create-service-principals#create-service-principal-for-azure-ad
[sp-create-cli]: https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest#create-a-service-principal
[built-in-roles]: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
[sp-assign-portal]: https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-create-service-principals#assign-the-service-principal-to-a-role
[sp-assign-cli]: https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest#manage-service-principal-roles
[sp-creds-portal]: https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-create-service-principals#get-credentials
[sp-creds-cli]: https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest#reset-credentials