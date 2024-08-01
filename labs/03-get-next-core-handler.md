[Building Serverless Solutions with Azure and .NET](https://github.com/TaleLearnCode/BuildingServerlessSolutions) \ [Beer City Code 2024](..\README.md) \ [Labs](README.md) \

# Lab 3: Get Next Core Handler

## Introduction

Returning to the Remanufacturing process, when a remanufacturing pod is ready for the next core to be remanufactured, they will send a message to the `sbt-GetNextCore` Service Bus topic. This message will be handled by a separate process that knows how to get information about the next core to be retrieved and then sends a message to the `sbt-OrderNextCore` Service Bus topic for processing.

## Objective

This lab exercise aims to enable attendees to build an Azure Function triggered by an Azure Service Bus topic subscription. This function will process incoming messages and send requests to the appropriate Production Schedule endpoint to retrieve information about the next core to be remanufactured. The Azure Function will forward these requests via Azure API Management, utilizing the mocked API response created in the previous lab exercise. By the end of this lab, participants will:

- Understand how to create and configure an Azure Function with a Service Bus trigger.
- Learn how to process messages from an Azure Service Bus topic subscription.
- Send requests to a Production Schedule endpoint using Azure API Management.
- Utilize the mocked API response for testing and validation.

## Prerequisites

- **Azure Subscription**: Access to an active Azure subscription with owner permissions.
- **Basic Knowledge of Azure Functions**: You should have gained familiarity with creating and deploying Azure Functions from completing [Lab 1 (Get Next Core)](01-get-next-core.md).
- **Azure Service Bus**: You should have gained a basic understanding of Azure Service Bus and its components from completing [Lab 1 (Get Next Core)](01-get-next-core.md).
- **Previous Lab Completion**: The [previous lab exercise](02-mock-production-schedule-endpoint.md) on creating a mocked API endpoint in Azure API Management has been completed.
- **Development Environment**: You have completed Lab 0 (Initialize Environment), which sets up your local and remote repository and creates the Azure services used in this lab exercise.

## Azure Services Descriptions

You learned about Azure Functions in [Lab 1 (Get Next Core](01-get-next-core.md)). In this lab, you will use the Service Bus Topic trigger, which allows you to respond to messages from a Service Bus topic.

### Key Details

- **Trigger Configuration**: You can configure a function triggered by messages from a Service Bus topic subscription using the `ServiceBusTrigger` attribute in your function code.
- **Message Processing**: When a message arrives in the specified topic subscription, the function is triggered and passed to the function for processing.
- **Session Support**: You can trigger on a session-enabled queue or topic, which allows for ordered message processing.
- **Scalability**: The Service Bus trigger supports scaling based on the number of messages in the topic subscription, ensuring efficient processing of large volumes of messages.

### Use Cases

- **Decoupling Microservices**: In a microservices architecture, different services need to communicate with each other without being tightly coupled. Use Service Bus topics to publish messages that multiple microservices can subscribe to. This allows each service to process messages independently and scale as needed.
- **Event-driven architectures**: Applications that need to react to events, such as user actions, system changes, or external triggers. Use Service Bus topics to broadcast events to multiple subscribers. Each subscriber can handle the event according to its logic, enabling a flexible and scalable event-driven system.
- **Load Leveling**: Systems that experience variable loads must balance the processing load over time. Use Service Bus topics to queue messages and process them steadily. This helps in managing peak loads and ensures that the system remains responsive.
- **Broadcasting Notifications**: Applications that need to send notifications to multiple users or systems. Use Service Bus topics to broadcast notifications to multiple subscribers, ensuring all relevant parties receive the information.
- **Data Integration**: Integrating data from various sources ensures that all systems have the latest information. Use Service Bus topics to publish data updates that multiple systems can subscribe to and synchronize their data accordingly.
- **Workflow Automation** Automates business processes that involve multiple steps and systems. Service Bus topics trigger different workflow stages, each handled by a different subscriber.
- **IoT Applications**L Collecting and processing data from a large number of IoT devices. Use Service Bus topics to aggregate data from devices and distribute it to various processing and analytics services.

## Steps

### Section 0: Open the Remanufacturing Solution

1. From Visual Studio, open the **Remanufacturing** solution.

### Section 1: Create the Get Next Core Handler Services

The next section will create a Service Bus topic subscription-triggered Azure Function. A good practice is to build class libraries that contain the bulk of the logic implemented by the Azure Functions and then make the Azure Functions very lightweight. The primary reason for doing this is to improve testing capabilities.

1. Right-click the **Get Next Core Handler** solution folder and select **Add** > **New Project...**

2. Search for and select **Class Library,** and then click the **Next** button.

3. In the **Configure your new project** dialog, provide the following values and then click the **Next** button.

   | Field        | Value                              |
   | ------------ | ---------------------------------- |
   | Project name | GetNextCoreHandler.Services        |
   | Location     | $TargetPath\src\GetNextCoreHandler |

4. On the **Additional information** dialog, ensure the `.NET 8.0 (Long Term Support)` is selected and click the **Create** button.

5. Delete the **Class1.cs** file.

6. Add references to the following projects:

   - JSONHelpers
   - Mesages
   - Responses
   - ServiceBusHelpers

7. Double-click the **GetNextCoreHandler.Services** project to open the GetNextCoreHandler.Services.csproj file.

8. Add the `<RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>` to the `PropertyGroup`. Your csproj file should look similar to:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
   
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <ImplicitUsings>enable</ImplicitUsings>
       <Nullable>enable</Nullable>
       <RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>
     </PropertyGroup>
   
     <ItemGroup>
       <ProjectReference Include="..\..\..\Core\JSONHelpers\JSONHelpers.csproj" />
       <ProjectReference Include="..\..\..\Core\Messages\Messages.csproj" />
       <ProjectReference Include="..\..\..\Core\Responses\Responses.csproj" />
       <ProjectReference Include="..\..\..\Core\ServiceBusHelpers\ServiceBusHelpers.csproj" />
     </ItemGroup>
   
   </Project>
   ```

9. Right-click the **GetNextCoreHandler.Services** project and click **Add** > **New folder**; name the folder Services.

10. Right-click the **Services** folder and select **Add** > **Class...**

11. Name the class **GetNextCoreServicesOptions.cs** and click the **Add** button.

12. Replace the default **GetNextCoreServicesOptions.cs** contents with:

    ```c#
    using Azure.Messaging.ServiceBus;
    
    namespace Remanufacturing.OrderNextCore.Services;
    
    public class GetNextCoreServicesOptions
    {
    	public ServiceBusClient ServiceBusClient { get; set; } = null!;
    	public string OrderNextCoreTopicName { get; set; } = null!;
    	public Dictionary<string, Uri> GetNextCoreUris { get; set; } = [];
    	public string ProductionScheduleAPIKeyKey { get; set; } = null!;
    	public string ProductionScheduleAPIKeyValue { get; set; } = null!;
    }
    ```

13. Right-click the **Services** folder and select **Add** > **Class...**

14. Name the class **GetNextCoreHandlerServices.cs** and click the **Add** button.

15. Replace the default **GetNextCoreHandlerServices.cs** contents with:

    ```c#
    using Remanufacturing.Extensions;
    using Remanufacturing.Messages;
    using Remanufacturing.Responses;
    using Remanufacturing.Services;
    using System.Net;
    
    namespace Remanufacturing.OrderNextCore.Services;
    
    public class GetNextCoreHandlerServices(GetNextCoreServicesOptions options)
    {
    
    	private readonly GetNextCoreServicesOptions _servicesOptions = options;
    
    	public async Task<IResponse> OrderNextCoreAsync(OrderNextCoreMessage orderNextCoreMessage, string instance)
    	{
    		try
    		{
    			ArgumentException.ThrowIfNullOrEmpty(orderNextCoreMessage.PodId, nameof(orderNextCoreMessage.PodId));
    			ArgumentException.ThrowIfNullOrEmpty(orderNextCoreMessage.CoreId, nameof(orderNextCoreMessage.CoreId));
    			if (orderNextCoreMessage.RequestDateTime == default)
    				orderNextCoreMessage.RequestDateTime = DateTime.UtcNow;
    			orderNextCoreMessage.MessageType = MessageTypes.OrderNextCore;
    			await ServiceBusServices.SendMessageAsync(_servicesOptions.ServiceBusClient, _servicesOptions.OrderNextCoreTopicName, orderNextCoreMessage);
    			return new StandardResponse()
    			{
    				Type = "https://httpstatuses.com/201", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
    				Title = "Request for next core sent.",
    				Status = HttpStatusCode.Created,
    				Detail = "The request for the next core has been sent to the warehouse.",
    				Instance = instance,
    				Extensions = new Dictionary<string, object>()
    				{
    					{ "PodId", orderNextCoreMessage.PodId },
    					{ "CoreId", orderNextCoreMessage.CoreId }
    				}
    			};
    		}
    		catch (ArgumentException ex)
    		{
    			return new ProblemDetails(ex, instance);
    		}
    		catch (Exception ex)
    		{
    			return new ProblemDetails()
    			{
    				Type = "https://httpstatuses.com/500", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
    				Title = "An error occurred while sending the message to the Service Bus",
    				Status = HttpStatusCode.InternalServerError,
    				Detail = ex.Message, // HACK: In a real-world scenario, you would not want to expose the exception message to the client.
    				Instance = instance
    			};
    		}
    	}
    
    	public async Task<IResponse> GetNextCoreAsync(HttpClient httpClient, OrderNextCoreMessage orderNextCoreMessage)
    	{
    		try
    		{
    
    			// Get the URI for the pod
    			if (!_servicesOptions.GetNextCoreUris.TryGetValue(orderNextCoreMessage.PodId, out Uri? getNextCoreUrl))
    				throw new ArgumentOutOfRangeException(nameof(orderNextCoreMessage.PodId), $"The pod ID '{orderNextCoreMessage.PodId}' is not valid.");
    			getNextCoreUrl = new Uri(getNextCoreUrl.ToString().Replace("{podId}", orderNextCoreMessage.PodId));
    			getNextCoreUrl = new Uri(getNextCoreUrl.ToString().Replace("{date}", orderNextCoreMessage.RequestDateTime.ToString("yyyy-MM-dd")));
    
    			// Add the subscription key to the request headers
    			httpClient.DefaultRequestHeaders.Add(_servicesOptions.ProductionScheduleAPIKeyKey, _servicesOptions.ProductionScheduleAPIKeyValue);
    
    			// Call the GetNextCore API operation
    			HttpResponseMessage httpResponse = await httpClient.GetAsync(getNextCoreUrl);
    
    			// Parse the response
    			httpResponse.EnsureSuccessStatusCode();
    			string responseBody = await httpResponse.Content.ReadAsStringAsync();
    			IResponse? response = responseBody.ToResponse();
    			return response ?? throw new InvalidOperationException("The response from the GetNextCore service was not in the expected format.");
    
    		}
    		catch (ArgumentException ex)
    		{
    			return new ProblemDetails(ex);
    		}
    		catch (Exception ex)
    		{
    			return new ProblemDetails()
    			{
    				Type = "https://httpstatuses.com/500", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
    				Title = "An error occurred while sending the message to the Service Bus",
    				Status = HttpStatusCode.InternalServerError,
    				Detail = ex.Message // HACK: In a real-world scenario, you would not want to expose the exception message to the client.
    			};
    		}
    	}
    
    }
    ```

16. Hit the **Ctrl** + **Shift** + **B** key combination to build the solution. Fix any errors.

### Section 2: Create the Get Next Core Handler Azure Function

1. Right-click the **Get Next Core Handler** solution folder and select **Add** > **New Project...**

2. Search for and select **Azure Functions,** and then click the **Next** button.

3. In the **Configure your new project** dialog, provide the following values and then click the **Next** button.

   | Field        | Value                              |
   | ------------ | ---------------------------------- |
   | Project name | GetNextCoreHandler.Functions       |
   | Location     | $TargetPath\src\GetNextCoreHandler |

4. On the **Additional information** dialog, specify the following values:

   | Field                                                        | Value                                  |
   | ------------------------------------------------------------ | -------------------------------------- |
   | Functions worker                                             | .NET 8.0 Isolated (Long Term Support)  |
   | Function                                                     | Service Bus Topic trigger              |
   | Use Azureite for runtime storage account (AzureWebJobsStorage) | Checked                                |
   | Enable container support                                     | Unchecked                              |
   | Connection string setting name                               | ServiceBusConnectionString             |
   | Topic name                                                   | %GetNextCoreTopicName%                 |
   | Subsription name                                             | %GetNextCoreForPod123SubscriptionName% |

5. Click the **Create** button.

6. Add a reference to the **GetNextCoreHandler.Services** project.

7. Double-click the **GetNextCoreHandler.Functions** project to open the GetNextCoreHandler.Functions.csproj file.

8. Add the `<RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>` to the `PropertyGroup`. Your csproj file should look similar to:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <AzureFunctionsVersion>v4</AzureFunctionsVersion>
       <OutputType>Exe</OutputType>
       <ImplicitUsings>enable</ImplicitUsings>
       <Nullable>enable</Nullable>
       <RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>
     </PropertyGroup>
     <ItemGroup>
       <FrameworkReference Include="Microsoft.AspNetCore.App" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.22.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.2.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore" Version="1.3.2" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.ServiceBus" Version="5.20.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.4" />
       <PackageReference Include="Microsoft.ApplicationInsights.WorkerService" Version="2.22.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="1.2.0" />
     </ItemGroup>
     <ItemGroup>
       <ProjectReference Include="..\GetNextCoreHandler\ClassLibrary1\GetNextCoreHandler.Services\GetNextCoreHandler.Services.csproj" />
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

9. Open the **Program.cs** class and replace the default content with the following:

   ```c#
   using Azure.Messaging.ServiceBus;
   using Microsoft.Azure.Functions.Worker;
   using Microsoft.Extensions.DependencyInjection;
   using Microsoft.Extensions.Hosting;
   using Remanufacturing.OrderNextCore.Services;
   
   GetNextCoreServicesOptions getNextCoreServicesOptions = new()
   {
   	ServiceBusClient = new ServiceBusClient(Environment.GetEnvironmentVariable("ServiceBusConnectionString")!),
   	OrderNextCoreTopicName = Environment.GetEnvironmentVariable("OrderNextCoreTopicName")!,
   	GetNextCoreUris = new Dictionary<string, Uri>()
   	{
   		// HACK: In a real-world scenario, you would want to set the URIs different so as to not hard-code them.
   		{ "Pod123", new Uri(Environment.GetEnvironmentVariable("GetNextCoreUri123")!) }
   	},
   	ProductionScheduleAPIKeyKey = Environment.GetEnvironmentVariable("ProductionScheduleAPIKeyKey")!,
   	ProductionScheduleAPIKeyValue = Environment.GetEnvironmentVariable("ProductionScheduleAPIKeyValue")!
   };
   
   IHost host = new HostBuilder()
   	.ConfigureFunctionsWebApplication()
   	.ConfigureServices(services =>
   	{
   		services.AddApplicationInsightsTelemetryWorkerService();
   		services.ConfigureFunctionsApplicationInsights();
   		services.AddSingleton(new GetNextCoreHandlerServices(getNextCoreServicesOptions));
   	})
   	.Build();
   
   host.Run();
   ```

10. Right-click the **GetNextCoreHandler.Functions** project and click **Add** > **New folder**; name the folder Functions.

11. Drag the **Function1.cs** file into the **Functions** folder.

12. Open the **Function1.cs** file and place your cursor on the function's name (`Function1`) .

13. Hit the **Ctrl** + **R** + **R** key combination and rename the class to `GetNextCoreHandler`, ensuring that the `Rename symbol's file` option is selected..

14. Replace the default **GetNextCoreHandler.cs** contents with:

    ```c#
    using Azure.Messaging.ServiceBus;
    using Microsoft.Azure.Functions.Worker;
    using Microsoft.Extensions.Logging;
    using Remanufacturing.Messages;
    using Remanufacturing.OrderNextCore.Services;
    using Remanufacturing.Responses;
    using System.Text.Json;
    
    namespace Remanufacturing.OrderNextCore.Functions;
    
    public class GetNextCoreHandler(
    	ILogger<GetNextCoreHandler> logger,
    	IHttpClientFactory httpClientFactory,
    	GetNextCoreHandlerServices getNextCoreHandlerServices)
    {
    	private readonly ILogger<GetNextCoreHandler> _logger = logger;
    	private readonly HttpClient _httpClient = httpClientFactory.CreateClient();
    	private readonly GetNextCoreHandlerServices _getNextCoreHandlerServices = getNextCoreHandlerServices;
    
    	[Function("GetNextCoreForPod123Handler")]
    	public async Task Run(
    		[ServiceBusTrigger("%GetNextCoreTopicName%", "%GetNextCoreForPod123SubscriptionName%", Connection = "ServiceBusConnectionString")] ServiceBusReceivedMessage message,
    		ServiceBusMessageActions messageActions)
    	{
    
    		_logger.LogInformation("Message ID: {id}", message.MessageId);
    
    		OrderNextCoreMessage? orderNextCoreMessage = JsonSerializer.Deserialize<OrderNextCoreMessage>(message.Body);
    		if (orderNextCoreMessage == null)
    		{
    			_logger.LogError("Failed to deserialize the message body.");
    			await messageActions.DeadLetterMessageAsync(message);
    			return;
    		}
    
    		_logger.LogInformation("Get next core for pod {podId}", orderNextCoreMessage.PodId);
    
    		IResponse getNextCoreInfoResponse = await _getNextCoreHandlerServices.GetNextCoreAsync(_httpClient, orderNextCoreMessage);
    		if (getNextCoreInfoResponse is StandardResponse response)
    		{
    			orderNextCoreMessage.CoreId = response.Extensions!["CoreId"].ToString();
    			orderNextCoreMessage.FinishedProductId = response.Extensions!["FinishedProductId"].ToString();
    		}
    		else
    		{
    			await messageActions.DeadLetterMessageAsync(message);
    			return;
    		}
    
    		IResponse orderNextCoreResponse = await _getNextCoreHandlerServices.OrderNextCoreAsync(orderNextCoreMessage, message.MessageId);
    		if (orderNextCoreResponse is ProblemDetails)
    		{
    			await messageActions.DeadLetterMessageAsync(message);
    			return;
    		}
    
    		// Complete the message
    		await messageActions.CompleteMessageAsync(message);
    
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

3. Get the name of the **Get Next Core** topic by:

   1. Make note of the full name of the **sbt-coolrevive-getnextcore** service bus topic.

4. Get the name of the **Get Next Core** subscription by:

   1. Click on the **sbt-coolrevive-getnextocre** service bus topic.
   2. In the **Subscriptions** listing, make note of the full name of the **sbts-CoolRevive-GetNextCore** subscription.

5. Get the API endpoint by:

   1. Search for `apim-CoolRevive` and select the API Management instance created during [Lab 0](00-initialize-environment.md).
   2. From the left-hand menu, select **APIs** > **APIs**.
   3. Select the **Production Schedule** API.
   4. Click the **Test** tab.
   5. Select the **Geet Next Core** operation.
   6. Remove the values for the `podId` and `date` template parameters.
   7. Make note of the **Request URL**.

6. Get the API Management subscription key by:

   1. From the `apim-CoolRevive` API Management instance, select **APIs** > **Subscriptions** from the left-hand menu.
   2. On the **Remanufacturing** entry, click the elipses (...) and select **Show/hide keys**.
   3. Make note of either the **Primary key** or **Seconary key** value.

7. Add the environment secrets to the Azure Function project by:

   1. Open the local.settings.json file
   2. Add a **ServiceBusConnectionString** key with the primary connection string you noted before.
   3. Add a **GetNextCoreTopicName** key with the full name of the **sbt-coolrevive-getnextcore** Service Bus topic.
   4. Add a **GetNextCoreForPod123SubscriptionName** key with the full name of the **sbt-coolrevive-getnextcore** Service Bus topic subscription.
   5. Add a **GetNextCoreUri123** key with the Request URL from the API Management API operation.
   6. Add a **OrderNextCoreTopicName** key with the full name of the **sbt-coolrevive-ordernextcore** Service Bus topic.
   7. Add a **ProductionScheduleAPIKeyKey** with the value of `Ocp-Apim-Subscription-Key`.
   8. Add a **ProductionScheduleAPIKeyValue** with the value of the key for the Remanufacturing API Management subscription.

   Your local.settings.json file should look similar to the following:

   ```json
   {
     "IsEncrypted": false,
     "Values": {
       "AzureWebJobsStorage": "UseDevelopmentStorage=true",
       "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
       "ServiceBusConnectionString": "<<ServiceBusConnectionString>>",
       "GetNextCoreTopicName": "sbns-coolrevive-getnextcore275-dev-use2",
       "GetNextCoreForPod123SubscriptionName": "sbts-CoolRevive-GetNextCore275-dev-use2",
       "GetNextCoreUri123": "https://apim-coolrevive275-dev-use2.azure-api.net/production-schedule/next-core/{podId}/{date}",
       "OrderNextCoreTopicName": "sbns-coolrevive-ordernextcore275-dev-use2",
       "ProductionScheduleAPIKeyKey": "Ocp-Apim-Subscription-Key",
       "ProductionScheduleAPIKeyValue": "<<SubscriptionKey>>"
     }
   }
   ```

8. Configure the startup projects for the solution by:

   1. Right-click on the **Remanufacturing** solution and selecting **Configure Startup Projects...**
   2. Select the **Multiple startup projects** option.
   3. Specify that the following projects are to Start:
      - GetNextCore.Functions
      - GetNextCoreHandler.Functions
   4. Click the **OK** button.

### Section 4: Test the Azure Function locally

1. Press **F5** to start the Azure Function apps locally.

   > The **GetNextCoreForPod123Handler** function should fire off immediately based upon the message generated from testing [Lab 1 (Get Next Core)](01-get-next-core.md). If it does not not, perform these actions:
   >
   > 1. Copy the **GetNextCore** endpoint.
   >
   > 2. Open Postman and enter the **GetNextCore** in the **Enter URL or paste text** field.
   >
   > 3. Change the HTTP method to **POST**.
   >
   > 4. Go the **Body** tab.
   >
   > 5. Select **raw**.
   >
   > 6. Paste the following into the request body field:
   >
   >    ```json
   >    {
   >        "MessageId": "message-123",
   >        "MessageType": "GetNextCore",
   >        "PodId": "Pod123"
   >    }
   >    ```
   >
   > 7. Click the **Send** button. You should receive a **201 Created** response with a response body similar to:
   >
   >    ```json
   >    {
   >        "type": "https://httpstatuses.com/201",
   >        "title": "Request for next core id sent.",
   >        "status": 201,
   >        "detail": "The request for the next core id has been sent to the Production Schedule.",
   >        "instance": "0HN547NP89O2R:00000001",
   >        "extensions": {
   >            "PodId": "Pod123"
   >        }
   >    }
   >    ```
   >
   > At this point, the **GetNextCoreForPod123Handler** function should trigger.

2. In the [Azure Portal](https://portal.azure.com), search for `sbns-CoolRevive` and select the Service Bus namespace created in [Lab 0 (Initialize environment)](00-initialize-environment.md), select **Entities** > **Topics** in the left-hand menu, click on the **sbt-coolrevive-ordernextcore** topic

3. Click the **Service Bus Explorer** menu item.

4. Select the `sbts-OrderNextCore` subscription and then click **Peak from start** button. You should see the message just sent to the Service Bus topic.

## Conclusion

In this lab exercise, you have successfully built an Azure Function triggered by an Azure Service Bus topic subscription. By completing this exercise, you have:

- Learned how to create and configure an Azure Function with a Service Bus trigger.
- Gained experience in processing messages from an Azure Service Bus topic subscription.
- Implemented logic to send requests to the Production Schedule endpoint via Azure API Management.
- Ultized the mocked API response created in the previous lab exercise for testing and validation.

These skills are essential for building event-driven and decoupled architectures, enabling you to create scalable and efficient solutions. You can apply these techniques to other projects, ensuring your applications can seamlessly handle complex workflows and integrations.

## Next Steps

In the next lab exercise, you will build the process for subscribing to the Order Next Core topic and updating inventory.