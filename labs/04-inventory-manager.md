[Building Serverless Solutions with Azure and .NET](https://github.com/TaleLearnCode/BuildingServerlessSolutions) \ [Beer City Code 2024](..\README.md) \ [Labs](README.md) \

# Lab 4: Inventory Manager

## Introduction

For now, Cool Revive requires a simple inventory management system that stores the status of each core using event-sourcing mechanisms. In future endeavors, the company looks to increase the capabilities of inventory management, but for now, they want to ensure the status of the cores is updated as updates happen.

In this hands-on lab exercise, you will build an Azure Function that is triggered by an Azure Service Bus topic subscription. This function will update the inventory status of a core within an Azure Cosmos DB SQL API database using event sourcing. Event sourcing is a powerful pattern that ensures all changes to the application state are stored as a sequence of events, providing a reliable and auditable way to manage state changes.

## Objective

The objective of this lab exercise is to enable you to create an Azure Function that processes messages from an Azure Service Bus topic subscription and updates the inventory status in an Azure Cosmos DB SQL API database using event sourcing. By the end of this lab, you will:

- Understand how to create an configure an Azure Function with a Service BUs trigger.
- Learn the principles of event sourcing and how it can be applied to update inventory status.
- Implement logic to update the inventory status of a core in Azure Cosmos Db.
- Gain practical experience in integrating Azure Functions with Azure Cosmos DB and Service Bus.

## Prerequisites

- **Azure Subscription**: Access to an active Azure subscription with owner permissions.
- **Basic Knowledge of Azure Functions**: You should have gained familiarity with creating and deploying Azure Functions from completing [Lab 1 (Get Next Core)](01-get-next-core.md).
- **Azure Service Bus**: After completing [Lab 1 (Get Next Core)](01-get-next-core.md) and [Lab 3 (Get Next Core Handler)](03-get-next-core-handler.md), you should have gained a basic understanding of Azure Service Bus and its components.
- **Previous Lab Completion**: The [previous lab exercise](03-get-next-core-handler.md) on creating a mocked API endpoint in Azure API Management has been completed.
- **Development Environment**: You have completed [Lab 0 (Initialize Environment)](00-initialize-environment.md), which sets up your local and remote repository and creates the Azure services used in this lab exercise.

## Azure Services Descriptions

You learned about Azure Functions in [Lab 1 (Get Next Core](01-get-next-core.md)) and the Service Bus Topic trigger in [Lab 3 (Get Next Core Handler)](03-get-next-core-handler.md). In this lab, you will also work with Cosmos DB, which is a fully managed, globally distributed, multi-model database service provided by Microsoft. It is designed to offer high availability, scalability, and low-latency access to data for modern applications. Here are some key aspects:

### Key Features

- **Global Distribution**
  - **Multi-Region Replication**: Cosmos DB can replicate your data across multiple Azure regions, ensuring high availability and low-latency access for users worldwide.
  - **Turnkey Global Distribution**: You can easily add or remove regions to your Cosmos DB account at any time without any downtime.
- **Multi-Model Support**
  - **Document**: Supports JSON documents, making it ideal for applications that need to store and query hierarchical data.
  - **Key-Value**: Allows for simple key-value pair storage.
  - **Graph**: Supports graph data models, enabling you to store and query graph data using the Gremlin API.
  - **Column-Family**: Supports wide-column stores, using the Apache Cassandra API.
  - **Table**: Supports table storage, using the same API as the Azure Table Storage service.
- **Performance and Scalability**
  - **Single-Digit Millisecond Latency**: Guarantees low-latency reads and writes.
  - **Elastic Scalability**: Automatically scales throughput and storage based on your application's needs.
  - **Serverless and Provisioned Throughput**: This service offers both serverless and provisioned throughput options, allowing you to choose the best pricing model for your workload.
- **Consistency Models**
  - **Five Consistency Levels**: This service offers five consistency levels (Strong, Bounded Staleness, Session, Consisten Prefix, and Eventual) to balance consistency and performance.
- **Integrated Security**
  - **Enterprise-Grade Security**: This product provides built-in security features, including encryption at rest, network isolation, and compliance with various industry standards.
- **Developer-Friendly**
  - **APIs and SDKs**: Supports multiple APIs (SQL, MongoDB, Cassandra, Gremlin, Table) and SDKs for popular programming languages.
  - **Querying**: Offers rich querying capabilities, including SQL-like queries for JSON data.

### Use Cases

- **IoT Applications**: Collect and process data from IoT devices in real-time.
- **E-Commerce**: Manage product catalogs, customer profiles, and order processing with low-latency access.
- **Gaming**: Store and retrieve player data, game state, and leaderboards
- **Social Media**: Handle user profiles, posts, and interactions with high availability and scalability.
- **Real-Time Analytics**: Perform real-time analytics on large volumes of data.

## Steps

### Section 0: Open the Remanufacturing Solution

1. From Visual Studio, open the **Remanufacturing** solution.

### Section 1: Create the Inventory Manager Services

The next section will create a Service Bus topic subscription-triggered Azure Function. A good practice is to build class libraries that contain the bulk of the logic implemented by the Azure Functions and then make the Azure Functions very lightweight. The primary reason for doing this is to improve testing capabilities.

1. Right-click the **Inventory Manager** solution folder and select **Add** > **New Project...**

2. Search for and select **Class Library,** and then click the **Next** button.

3. In the **Configure your new project** dialog, provide the following values and click the **Next** button.

   | Field        | Value                            |
   | ------------ | -------------------------------- |
   | Project name | InventoryManager.Services        |
   | Location     | $TargetPath\src\InventoryManager |

4. On the **Additional information** dialog, ensure the `.NET 8.0 (Long Term Support)` is selected and click the **Create** button.

5. Delete the **Class1.cs** file.

6. Add a reference to the following projects:

   - JSONHelpers
   - Messages

7. Add a reference to the Azure.Messaging.ServiceBus NuGet package.

8. Double-click the **InventoryManager.Services** project to open the InventoryManager.Services.csproj file.

9. Add the `<RootNamespace>Remanufacturing.InventoryManager</RootNamespace>` to the `PropertyGroup`. Your csproj file should look similar to:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
   
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <ImplicitUsings>enable</ImplicitUsings>
       <Nullable>enable</Nullable>
       <RootNamespace>Remanufacturing.InventoryManager</RootNamespace>
     </PropertyGroup>
   
     <ItemGroup>
       <PackageReference Include="Azure.Messaging.ServiceBus" Version="7.18.0" />
     </ItemGroup>
   
     <ItemGroup>
       <ProjectReference Include="..\..\Core\JSONHelpers\JSONHelpers.csproj" />
       <ProjectReference Include="..\..\Core\Messages\Messages.csproj" />
     </ItemGroup>
   
   </Project>
   ```

10. Right-click the **InventoryManager.Services** project and click **Add** > **New folder**; name the folder Entities.

11. Right-click the **Entities** folder and select **Add** > **Class...**

12. Name the class **InventoryEventEntity.cs** and click the **Add** button.

13. Replace the default **InventoryEventEntity.cs** contents with:

    ```c#
    using System.Text.Json.Serialization;
    
    namespace Remanufacturing.InventoryManager.Entities;
    
    public class InventoryEventEntity
    {
    	[JsonPropertyName("id")]
    	public string Id { get; set; } = Guid.NewGuid().ToString();
    
    	[JsonPropertyName("eventType")]
    	public string EventType { get; set; } = null!;
    
    	[JsonPropertyName("finishedProductId")]
    	public string FinishedProductId { get; set; } = null!;
    
    	[JsonPropertyName("podId")]
    	public string PodId { get; set; } = null!;
    
    	[JsonPropertyName("coreId")]
    	public string CoreId { get; set; } = null!;
    
    	[JsonPropertyName("status")]
    	public string Status { get; set; } = null!;
    
    	[JsonPropertyName("statusDetail")]
    	public string StatusDetail { get; set; } = null!;
    
    	[JsonPropertyName("eventTimestamp")]
    	public string EventTimestamp { get; set; } = DateTime.UtcNow.ToString();
    
    }
    ```

14. Right-click the **Entities** folder and select **Add** > **Class...**

15. Name the class **InventoryEventTypes.cs** and click the **Add** button.

16. Replace the default **InventoryEventTypes.cs** contents with:

    ```c#
    namespace Remanufacturing.InventoryManager.Entities;
    
    public static class InventoryEventTypes
    {
    	public const string OrderNextCore = "OrderNextCore";
    }
    ```

17. Right-click the **InventoryManager.Services** project and click **Add** > **New folder**; name the folder Extensions.

18. Right-click the **Extensions** folder and select **Add** > **Class...**

19. Name the class **InventoryEventEntityExtensions.cs** and click the **Add** button.

20. Replace the default **InventoryEventEntityExtensions.cs** contents with:

    ```c#
    using Azure.Messaging.ServiceBus;
    using Remanufacturing.Helpers;
    using Remanufacturing.InventoryManager.Entities;
    using Remanufacturing.Messages;
    using System.Text.Json;
    
    namespace Remanufacturing.InventoryManager.Extensions;
    
    public static class InventoryEventEntityExtensions
    {
    
    	public static InventoryEventEntity? ToInventoryEventEntity(this ServiceBusReceivedMessage serviceBusReceivedMessage)
    	{
    
    		ArgumentException.ThrowIfNullOrWhiteSpace(nameof(serviceBusReceivedMessage));
    
    		JsonSerializerOptions options = new();
    		options.Converters.Add(new InterfaceConverter<IMessage, ConcreteMessage>());
    		IMessage? deserializedMessage = JsonSerializer.Deserialize<IMessage>(serviceBusReceivedMessage.Body.ToString(), options);
    
    		if (deserializedMessage == null)
    		{
    			return null;
    		}
    		else if (deserializedMessage.MessageType == MessageTypes.OrderNextCore)
    		{
    			InventoryEventEntity orderNextCoreMessage = JsonSerializer.Deserialize<InventoryEventEntity>(serviceBusReceivedMessage.Body.ToString())!;
    			return new()
    			{
    				Id = serviceBusReceivedMessage.MessageId,
    				EventType = InventoryEventTypes.OrderNextCore,
    				FinishedProductId = orderNextCoreMessage.FinishedProductId,
    				PodId = orderNextCoreMessage.PodId,
    				CoreId = orderNextCoreMessage.CoreId,
    				Status = orderNextCoreMessage.Status,
    				StatusDetail = null
    			};
    		}
    		else
    		{
    			return null;
    		}
    
    	}
    
    }
    ```

21. Hit the **Ctrl** + **Shift** + **B** key combination to build the solution. Fix any errors.

### Section 2: Create the Inventory Manager Azure Function

1. Right-click the **Inventory Manager** solution folder and select **Add** > **New Project...**

2. Search for and select **Azure Functions,** and then click the **Next** button.

3. In the **Configure your new project** dialog, provide the following values and then click the **Next** button.

   | Field        | Value                            |
   | ------------ | -------------------------------- |
   | Project name | InventoryManager.Functions       |
   | Location     | $TargetPath\src\InventoryManager |

4. On the **Additional information** dialog, specify the following values:

   | Field                                                        | Value                                 |
   | ------------------------------------------------------------ | ------------------------------------- |
   | Functions worker                                             | .NET 8.0 Isolated (Long Term Support) |
   | Function                                                     | Service Bus Topic trigger             |
   | Use Azureite for runtime storage account (AzureWebJobsStorage) | Checked                               |
   | Enable container support                                     | Unchecked                             |
   | Connection string setting name                               | ServiceBusConnectionString            |
   | Topic name                                                   | %OrderNextCoreTopicName%              |
   | Subscription name                                            | %OrderNextCoreSubscriptionName%       |

5. Click the **Create** button.

6. Add a reference to the **InventoryManager.Services** project.

7. Add a reference to the **Microsoft.Azure.Functions.Worker.Extensions.CosmosDB** NuGet package

8. Double-click the **InventoryManager.Functions** project to open the GetNextCoreHandler.Functions.csproj file.

9. Add the `<RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>` to the `PropertyGroup`. Your csproj file should look similar to:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <AzureFunctionsVersion>v4</AzureFunctionsVersion>
       <OutputType>Exe</OutputType>
       <ImplicitUsings>enable</ImplicitUsings>
       <Nullable>enable</Nullable>
       <RootNamespace>Remanufacturing.InventoryManager</RootNamespace>
     </PropertyGroup>
     <ItemGroup>
       <FrameworkReference Include="Microsoft.AspNetCore.App" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.22.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.CosmosDB" Version="4.10.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.2.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore" Version="1.3.2" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.ServiceBus" Version="5.20.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.4" />
       <PackageReference Include="Microsoft.ApplicationInsights.WorkerService" Version="2.22.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="1.2.0" />
     </ItemGroup>
     <ItemGroup>
       <ProjectReference Include="..\InventoryManager.Services\InventoryManager.Services.csproj" />
     </ItemGroup>
     <ItemGroup>
       <None Update="host.json">
         <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
       </None>
       <None Update="local.settings.json">
         <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
         <CopyToPublishDirectory>Never</CopyToPublishDirectory>
       </None>
     </ItemGroup>
     <ItemGroup>
       <Using Include="System.Threading.ExecutionContext" Alias="ExecutionContext" />
     </ItemGroup>
   </Project>
   ```

10. Right-click the **InventoryManager.Functions** project and click **Add** > **New folder**; name the folder Functions.

11. Drag the **Function1.cs** file into the **Functions** folder.

12. Open the **Function1.cs** file and place your cursor on the function's name (`Function1`) .

13. Hit the **Ctrl** + **R** + **R** key combination and rename the class to `OrderNextCoreHandler`, ensuring that the `Rename symbol's file` option is selected..

14. Replace the default **OrderNextCoreHandler.cs** contents with:

    ```c#
    using Azure.Messaging.ServiceBus;
    using Microsoft.Azure.Functions.Worker;
    using Microsoft.Extensions.Logging;
    using Remanufacturing.InventoryManager.Entities;
    using Remanufacturing.InventoryManager.Extensions;
    
    namespace Remanufacturing.InventoryManager.Functions;
    
    public class OrderNextCoreHandler(ILogger<OrderNextCoreHandler> logger)
    {
    	private readonly ILogger<OrderNextCoreHandler> _logger = logger;
    
    	[Function(nameof(OrderNextCoreHandler))]
    	[CosmosDBOutput(
    		databaseName: "%EventSourceDatabaseName%",
    		containerName: "%EventSourceContainerName%",
    		PartitionKey = "%EventSourcePartitionKey%",
    		Connection = "CosmosDBConnectionString",
    		CreateIfNotExists = false)]
    	public async Task<InventoryEventEntity?> RunAsync(
    		[ServiceBusTrigger("%OrderNextCoreTopicName%", "%OrderNextCoreSubscriptionName%", Connection = "ServiceBusConnectionString")] ServiceBusReceivedMessage message,
    		ServiceBusMessageActions messageActions)
    	{
    		_logger.LogInformation("Message ID: {id}", message.MessageId);
    		_logger.LogInformation("Message Body: {body}", message.Body);
    		_logger.LogInformation("Message Content-Type: {contentType}", message.ContentType);
    
    		InventoryEventEntity? inventoryEventEntity = message.ToInventoryEventEntity();
    
    		// Complete the message
    		await messageActions.CompleteMessageAsync(message);
    
    		// Save the message to the Cosmos DB
    		return inventoryEventEntity;
    
    	}
    
    }
    ```

15. Hit the **Ctrl** + **Shift** + **B** key combination to build the solution. Fix any errors.

### Section 3: Prepare for Local Testing

1. Retrieve the Service Bus connection string by:

   1. From the [Azure Portal](htttps://portal.azure.com), search for `sbns-CoolRevive` and select the Service Bus Namespace created during [Lab 0](00-initialize-environment.md).
   2. Click on **Settings** > **Shared access policies**.
   3. Click on **RootManageSharedAccessKey**.
   4. Make note of the Primary Connection String.

2. Get the name of the **Order Next Core** topic by:

   1. Click on **Entities** > **Topics**.
   2. Make note of the full name of the **sbt-coolrevive-ordernextcore** service bus topic.

3. Get the name of the **Inventory Management** subscription by:

   1. Click on the **sbt-coolrevive-ordernextcore** service bus topic.
   2. In the **Subscriptions** listing, make note of the full name of the **sbts-CoolRevive-ONC-InventoryManager** subscription.

4. Get the Cosmos DB connection string by:

   1. In the Azure Portal, search for `cosno-coolrevive-invmgr` and select the Cosmos DB account created during [Lab 0](00-initialize-environment.md).
   2. In the left-hand menu, select **Settings** > **Keys**.
   3. Make note of either the primary or secondary connection string.

5. Add the environment secrets to the Azure Function project by:

   1. Open the local.settings.json file
   2. Add a **ServiceBusConnectionString** key with the primary connection string you noted before.
   3. Add a **OrderNextCoreTopicName** key with the full name of the **sbt-coolrevive-ordernextcore** Service Bus topic.
   4. Add a **OrderNextCoreSubscriptionName** key with the full name of the **sbt-CoolRevive-ONC-InventoryManager** Service Bus topic subscription.
   5. Add a **CosmosDBConnectionString** key with the Cosmos DB connection string.
   6. Add a **EventSourceDatabaseName** key with the value of **inventory-manager**.
   7. Add a **EventSourceContainerName** key with the value ofinventory-manager-events.
   8. Add a **EventSourcePartitionKey** key with the value of **/finishedProductId**.

   Your local.settings.json file should look similar to the following:

   ```json
   {
     "IsEncrypted": false,
     "Values": {
       "AzureWebJobsStorage": "UseDevelopmentStorage=true",
       "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
       "ServiceBusConnectionString": "ServiceBusConnectionString",
       "OrderNextCoreTopicName": "OrderNextCoreTopicName",
       "OrderNextCoreSubscriptionName": "OrderNextCoreSubscriptionName",
       "CosmosDBConnectionString": "CosmosDBConnectionString",
       "EventSourceDatabaseName": "inventory-manager",
       "EventSourceContainerName": "inventory-manager-events",
       "EventSourcePartitionKey": "/finishedProductId"
     }
   }
   ```

6. Configure the startup projects for the solution by:

   1. Right-click on the **Remanufacturing** solution and selecting **Configure Startup Projects...**
   2. Select the **Multiple startup projects** option.
   3. Specify that the following projects are to Start:
      - GetNextCore.Functions
      - GetNextCoreHandler.Functions
      - InventoryManager.Functions
   4. Click the **OK** button.

### Section 4: Test the Azure Function locally

1. Press **F5** to start the Azure Function apps locally.

2. Copy the **GetNextCore** endpoint.

3. Open Postman and enter the **GetNextCore** in the **Enter URL or paste text** field.

4. Change the HTTP method to **POST**.

5. Go the **Body** tab.

6. Select **raw**.

7. Paste the following into the request body field:

   ```json
   {
       "MessageId": "message-123",
       "MessageType": "GetNextCore",
       "PodId": "Pod123"
   }
   ```

   

8. Click the **Send** button. You should receive a **201 Created** response with a response body similar to:

   ```json
   {
       "type": "https://httpstatuses.com/201",
       "title": "Request for next core id sent.",
       "status": 201,
       "detail": "The request for the next core id has been sent to the Production Schedule.",
       "instance": "0HN547NP89O2R:00000001",
       "extensions": {
           "PodId": "Pod123"
       }
   }
   ```

   > At this point, you should see The **GetNextCoreForPod123Handler** Azure Function fire, and then shortly afterward, the **OrderNextCoreHandler** Azure Function will fire.

9. In the [Azure Portal](https://portal.azure.com), search for `cosno-coolrevive-invmgr` and select the Cosmos DB account created in [Lab 0 (Initialize environment)](00-initialize-environment.md).

10. From the left-hand menu, click the **Data Explorer** option.

11. Click the **Service Bus Explorer** menu item.

12. Click on the **inventory-manager-events** container and then click on **Items**.

13. Verify that you see the record that should have just been saved to the container. The record should simliar to this:

    ```json
    {
        "id": "bfa4a30efb5345c0a6671a1dcf1f7c23",
        "eventType": "OrderNextCore",
        "finishedProductId": null,
        "podId": null,
        "coreId": null,
        "status": null,
        "statusDetail": null,
        "eventTimestamp": "7/29/2024 3:32:33 AM",
        "_rid": "BGoCAJxK1mwBAAAAAAAAAA==",
        "_self": "dbs/BGoCAA==/colls/BGoCAJxK1mw=/docs/BGoCAJxK1mwBAAAAAAAAAA==/",
        "_etag": "\"eb0075c0-0000-0200-0000-66a70d540000\"",
        "_attachments": "attachments/",
        "_ts": 1722223956
    }
    ```

    

## Conclusion

In this lab exercise, you successfully built an Azure Function triggered by an Azure Service Bus subscription to update the inventory status in an Azure Cosmos DB SQL API database using event sourcing. By completing this exercise, you have:

- Learned how to create and configure an Azure Function with a Service Bus topic trigger.
- Gained an understanding of event sourcing and its application in updating inventory status.
- Implemented logic to process messages and update the inventory status in Azure Cosmos DB.
- Tested the integration between Azure Service Bus, Azure Functions, and Azure Cosmos DB.

These skills are crucial for building robust, scalable, and event-driven applications. You can now apply these techniques to other projects, ensuring that your applications can efficiently handle complex workflows and state management.

## Next Steps

In the next lab exercise, you will create the Warehouse and Conveyance processing. These are two systems outside the Remanufacturing system but are crucial to the Order Next Core process. So, for this workshop, we will create simulations of their functionality.