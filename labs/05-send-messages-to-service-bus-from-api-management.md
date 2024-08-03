[Building Serverless Solutions with Azure and .NET](https://github.com/TaleLearnCode/BuildingServerlessSolutions) \ [Beer City Code 2024](..\README.md) \ [Labs](README.md) \

# Lab 5: Send Messages to Service Bus from API Management

## Introduction

Cool Revive has multiple systems that need to participate in the remanufacturing process, but do not have the ability to send messages to Service Bus. A nice feature of Azure Service Bus is its REST API which can be used to send, read, and manage messages. But this requires sharing SAS Tokens which makes management hard.

A great way around this is to have an Azure API Management operation that provides a front-door to the Service Bus topics and queues.

## Objective

The objective of this lab exercise is to show you how to create an Azure API Management operation that forwards messages to an Azure Service Bus topic. You will set up the necessary policies in API Management to route 

## Prerequisites

- **Azure Subscription**: Access to an active Azure subscription with owner permissions.
- **Basic Knowledge of Azure Functions**: You should have gained familiarity with creating and deploying Azure Functions from completing [Lab 1 (Get Next Core)](01-get-next-core.md).
- **Azure Service Bus**: After completing [Lab 1 (Get Next Core)](01-get-next-core.md) and [Lab 3 (Get Next Core Handler)](03-get-next-core-handler.md), you should have gained a basic understanding of Azure Service Bus and its components.
- **Previous Lab Completion**: The [previous lab exercise](04-inventory-manager.md) on building the initial Inventory Manager functionality.
- **Development Environment**: You have completed [Lab 0 (Initialize Environment)](00-initialize-environment.md), which sets up your local and remote repository and creates the Azure services used in this lab exercise.

## Azure Services Descriptions

In this lab, you will be working with Azure API Management which we discussed in [Lab 2 (Mock Production Schedule Endpoint](02-mock-production-schedule-endpoint.md) and Azure Service Bus which we discussed in [Lab 1 (Get Next Core)](01-get-next-core.md).

## Steps

### Section 1: Generate Shared Access Signature (SAS) Token

A Shared Access Signature (SAS) token is a security mechanism used in Azure cloud services like Azure Storage, **Azure Service Bus**, and Azure Cosmos DB. SAS tokens allow you to grant **limited access** to specific resources within these services without directly sharing your account access keys.

1. Retrieve the shared access policy key from Azure Service Bus by:

   1. From the [Azure Portal](https://portal.azure.com), search for `sbns-CoolRevive` and select the Service Bus namespace created at the beginning of the workshop.
   2. From the left-hand menu, go to **Settings** > **Shared access policies**.
   3. Click on the **APIMSend** policy.
   4. Make note of the Primary Key. 

2. Retrieve the URL for the `sbt-CoolRevive-NextCoreInTransit` topic by:

   1. From the left-hand menu, go to **Entities** > **Topics**.
   2. Click on the the `sbt-CoolRevive-NextCoreInTransit` topic.
   3. Make note of the **Topic URL**

3. Generate the SAS token by executing the following in PowerShell:

   ```powershell
   $URI="https://{{service-bus-topic-url}}"
   $Access_Policy_Name="APIMSend"
   $Access_Policy_Key="{{access-policy-key}}"
   $Expires=([DateTimeOffset]::Now.ToUnixTimeSeconds())+31587840
   $SignatureString=[System.Web.HttpUtility]::UrlEncode($URI)+ "`n" + [string]$Expires
   $HMAC = New-Object System.Security.Cryptography.HMACSHA256
   $HMAC.key = [Text.Encoding]::ASCII.GetBytes($Access_Policy_Key)
   $Signature = $HMAC.ComputeHash([Text.Encoding]::ASCII.GetBytes($SignatureString))
   $Signature = [Convert]::ToBase64String($Signature)
   $SASToken = "SharedAccessSignature sr=" + [System.Web.HttpUtility]::UrlEncode($URI) + "&sig=" + [System.Web.HttpUtility]::UrlEncode($Signature) + "&se=" + $Expires + "&skn=" + $Access_Policy_Name
   $SASToken
   ```

   - Replace `{{service-bus-topic-url}}` with the Topic URL from above.
   - Replace `{{access-policy-key}}` with the Primary Key captured above.

   Make note the generated **SAS Token**.

### Section 2: Add the SAS Token to Azure API Management

1. In the [Azure Portal](https://azure.portal.com), search for `apim-coolrevive` and select the API Management instance created at the beginning of the workshop.

2. From the left-hand menu, select **APIs** > **Named values**.

3. Click the **+ Add** button.

4. Supply the following values:

   | Field        | Value                                                |
   | ------------ | ---------------------------------------------------- |
   | Name         | next-core-in-transit-sas-token                       |
   | Display name | next-core-in-transit-sas-token                       |
   | Type         | Secret                                               |
   | Value        | The **SAS Token** generated in the previous section. |

5. Click the **Save** button.

### Section 3: Create a Product

To publish the API we are about to create, you need a product within API Management. Products let you group APIs and define terms of use and runtime policies. API consumers can subscribe to a product to obtain a key to call the APIs within the product.

1. In the left-hand menu, select **APIs** > **Products**.

2. Click the **+ Add** button.

3. Provide the following values:

   | Field                 | Value                                                        |
   | --------------------- | ------------------------------------------------------------ |
   | Display Name          | Remanufacturing                                              |
   | Id                    | remanufacturing                                              |
   | Description           | Provides the ability to interact with the Remanufacturing system. |
   | Published             | Checked                                                      |
   | Requires subscription | Checked                                                      |
   | Requires approve      | Unchecked                                                    |

4. Click the **Create** button.

### Section 4: Create a New API

1. In the left-hand menu, select **APIs** > **APIs**.

2. On the **Define a new API** page, click on **HTTP**, which will allow you to define an HTTP API manually.

3. On the **Create an HTTP API** dialog, select **Full** and then fill in the fields as specified below

   | Field             | Value                                                        |
   | ----------------- | ------------------------------------------------------------ |
   | Display name      | Order Next Core                                              |
   | Name              | order-next-core                                              |
   | Description       | Provides endpoints to interact with the Remanufacturing Order Next Core service. |
   | API URL suffix    | remanufacturing/order-next-core                              |
   | Products          | Remanufacturing                                              |
   | Gateways          | Managed                                                      |
   | Version this API? | Unchecked                                                    |

4. Click the **Create** button.

### Section 5: Define the Next Core in Transit Operation

1. In the API settings, click on **+ Add Operation**.

2. Fill in the details for the operation:

   | Field             | Value                                                 |
   | ----------------- | ----------------------------------------------------- |
   | Display name      | Next Core in Transit                                  |
   | Name              | next-core-in-transit                                  |
   | URL (HTTP Method) | POST                                                  |
   | URL               | next-core-in-transit                                  |
   | Description       | Posts information about the transit status of a core. |

3. Click the **Save** button.


### Section 6: Define Policies to Forward Inbound Traffic to Service Bus

1. Click on the **Next Core in Transit** operation.

2. In the **Inbound processing** pane, click the **</>** button.

3. Replace the default content with:

   ```xml
   <policies>
       <inbound>
           <base />
           <!-- Gets the Logic App Info from Headers automatically provided -->
           <set-header name="Authorization" exists-action="override">
               <value>{{next-core-in-transit-sas-token}}</value>
           </set-header>
           <set-header name="BrokerProperties" exists-action="override">
               <value>@{
                        var json = new JObject();
                        json.Add("MessageId", context.RequestId);
                        return json.ToString(Newtonsoft.Json.Formatting.None);
               }</value>
           </set-header>
           <set-backend-service base-url="<<service-bus-topic-url>>" />
       </inbound>
       <backend>
           <base />
       </backend>
       <outbound>
           <base />
       </outbound>
       <on-error>
           <base />
           <set-variable name="errorMessage" value="@{
               return new JObject(
                   new JProperty("EventTime", DateTime.UtcNow.ToString()),
                   new JProperty("ErrorMessage", context.LastError.Message),
                   new JProperty("ErrorReason", context.LastError.Reason),
                   new JProperty("ErrorSource", context.LastError.Source),
                   new JProperty("ErrorScope", context.LastError.Scope),
                   new JProperty("ErrorSection", context.LastError.Section)
    
               ).ToString();
           }" />
           <return-response>
               <set-status code="500" reason="Error" />
               <set-header name="Content-Type" exists-action="override">
                   <value>application/json</value>
               </set-header>
               <set-body>@((string)context.Variables["errorMessage"])</set-body>
           </return-response>
       </on-error>
   </policies>
   ```

   - Replace `<<service-bus-topic-url>>` with the Topic URL you made of a note of before.

## Conclusion

In this hands-on lab, you have configured an Azure API Management operation to forward messages to an Azure Service Bus topic. You learned how to set up policies in API Management for routing traffic to the Service Bus. Armed with this knowledge, you are now equipped to integrate API Management and Service Bus effectively in their applications.