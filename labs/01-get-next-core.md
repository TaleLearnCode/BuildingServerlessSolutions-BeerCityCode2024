[Building Serverless Solutions with Azure and .NET](https://github.com/TaleLearnCode/BuildingServerlessSolutions) \ [Beer City Code 2024](..\README.md) \ [Labs](README.md) \

# Lab 1: Get Next Core

## Objective

The first step of the Order Next Core process is to retrieve details on the next core to be remanufactured from the legacy Production Schedule system. We determined that this can happen through multiple means, not all allowing for synchronous operation. As such, we will implement an asynchronous mechanism to retrieve the next core information. In this lab, you will build the very first part of this operation, which will provide a RESTful endpoint whose responsibility is to process the request and send the appropriate message to the **Get Next Core** Service Bus topic.

## Azure Services Descriptions

In this lab, you will build an Azure Function app. Azure Functions is a serverless compute service that allows you to run trigger-driven code without explicitly provisioning or managing infrastructure. Here are some key points:

- **Triggered-Driven**: Azure Functions are triggered by various events, such as HTTP requests, timers, database changes, and messages from queues or topics.
- **Scalability**: Functions automatically scale based on demand, ensuring that your application can handle varying loads efficiently.
- **Cost-Effective**: You only pay for the execution time of your functions (unless you are using Always Ready instances), making it a cost-effective solution for many use cases.
- **Multiple Languages**: You can write functions in various languages, including C#, JavaScript, Python, Java, and PowerShell.
- **Integration**: Azure Functions integrates seamlessly with other Azure services, such as Azure Storage, Event Hubs, and Service Bus.

## Steps

### Section 0: Open the Remanufacturing Solution

Start by opening the Remanufacturing solution in Visual Studio at `$TargetPath\src\Remanufacturing.sln`.

### Section 1: Create the JSON Helper Library

There are some common functionality in regards to handling JSON objects that we will put into a core library for future use.

1. Right-click the **Core** solution folder and click **Add** > **New Project**.

2. Search for and select *Class Library* and click the **Next** button.

3. In the **Configure your new project** dialog, provide the following values and then click the **Next** button.

   | Field        | Value                |
   | ------------ | -------------------- |
   | Project name | JSONHelpers          |
   | Location     | $TargetPath\src\Core |

4. On the **Additional information** dialog, ensure the `.NET 8.0 (Long Term Support)` is selected and click the **Create** button.

5. Delete the **Class1.cs** file.

6. Double-click the **JSONHelpers** project to open the Messages.csproj file.

7. Add the `<RootNamespace>Remanufacturing</RootNamespace>` to the `PropertyGroup`. Your csproj file should look similar to:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
   
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <ImplicitUsings>enable</ImplicitUsings>
       <Nullable>enable</Nullable>
       <RootNamespace>Remanufacturing</RootNamespace>
     </PropertyGroup>
   
   </Project>
   ```

8. Right-click the **JSONHelpers** project and click **Add** > **New folder**; name the folder Helpers.

9. Right-click the **Helpers** folder and click **Add > Class**; name the class **InterfaceConverter.cs**, and click the **Add** button. Replace the default text with:

   ```c#
   using System.Text.Json;
   using System.Text.Json.Serialization;
   
   namespace Remanufacturing.Helpers;
   
   public class InterfaceConverter<TInterface, TConcrete> : JsonConverter<TInterface>
   		where TConcrete : TInterface, new()
   {
   	public override TInterface? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
   	{
   		var jsonDocument = JsonDocument.ParseValue(ref reader);
   		var jsonObject = jsonDocument.RootElement.GetRawText();
   		return JsonSerializer.Deserialize<TConcrete>(jsonObject, options);
   	}
   
   	public override void Write(Utf8JsonWriter writer, TInterface value, JsonSerializerOptions options)
   	{
   		JsonSerializer.Serialize(writer, (TConcrete)value!, options);
   	}
   }
   ```



### Section 2: Create the Message Class Library

To aid the different components in writing and reading the different messages, we will create a Messages class library containing plain C# classes representing the messages within the Remanufacturing system.

1. Right-click the **Core** solution folder and click **Add** > **New Project**.

2. Search for and select *Class Library* and click the **Next** button.

3. In the **Configure your new project** dialog, provide the following values and then click the **Next** button.

   | Field        | Value                |
   | ------------ | -------------------- |
   | Project name | Messages             |
   | Location     | $TargetPath\src\Core |

4. On the **Additional information** dialog, ensure the `.NET 8.0 (Long Term Support)` is selected and click the **Create** button.

5. Delete the **Class1.cs** file.

6. Double-click the **Messages** project to open the Messages.csproj file.

7. Add the `<RootNamespace>Remanufacturing</RootNamespace>` to the `PropertyGroup`. Your csproj file should look similar to:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
   
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <ImplicitUsings>enable</ImplicitUsings>
       <Nullable>enable</Nullable>
       <RootNamespace>Remanufacturing</RootNamespace>
     </PropertyGroup>
   
   </Project>
   ```

8. Right-click the **Messages** project and click **Add** > **New folder**; name the folder Messages.

9. Right-click the **Messages** folder and click **Add > Class**; name the class **MessageTypes.cs**, and click the **Add** button. Replace the default text with:

   ```c#
   namespace Remanufacturing.Messages;
   
   public static class MessageTypes
   {
   	public const string OrderNextCore = "OrderNextCore";
   }
   ```

10. Right-click the **Messages** folder and click **Add** > **New Item**; select Interface; name the interface **IMessage.cs**; and click the **Add** button. Replace the default text with:

    ```c#
    namespace Remanufacturing.Messages;
    
    /// <summary>
    /// Interface for Cool Revive Remanufacturing messages.
    /// </summary>
    public interface IMessage
    {
    
    	/// <summary>
    	/// Gets or sets the tracking identifier for the message.
    	/// </summary>
    	string MessageId { get; set; }
    
    	/// <summary>
    	/// Gets or sets the type of the message.
    	/// </summary>
    	string MessageType { get; set; }
    }
    ```

11. Right-click the **Messages** folder and click the **Add** > **Class...**; name the class **OrderNextCoreMessage.cs**; and click the **Add** button. Replace the default text with:

    ```c#
    namespace Remanufacturing.Messages;
    
    public class OrderNextCoreMessage : IMessage
    {
    	public string MessageId { get; set; } = Guid.NewGuid().ToString();
    	public string MessageType { get; set; } = MessageTypes.OrderNextCore;
    	public string PodId { get; set; } = null!;
    	public string? CoreId { get; set; }
    	public string? FinishedProductId { get; set; }
    	public DateTime RequestDateTime { get; set; }
    }
    ```

12. Right-click the **Messages** folder and click the **Add** > **Class...**; name the class **ConcreteMessage.cs**; and click the **Add** button. Replace the default text with:

    ```c#
    #nullable disable
    
    namespace Remanufacturing.Messages;
    
    internal class ConcreteMessage : IMessage
    {
    	public string MessageId { get; set; }
    	public string MessageType { get; set; }
    }
    ```

### Section 3: Create the Responses Class Library

[RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) defines a problem detail response as sending back details of errors in an HTTP response. The Remanufacturing system uses the problem detail response andprovidesextends it to a standard response. This ensures that developers within the system or externally will always receive responses formatted in a familiar format.

1. Right-click the **Core** solution folder and click **Add** > **New Project**.

2. Search for and select *Class Library* and click the **Next** button.

3. In the **Configure your new project** dialog, provide the following values and then click the **Next** button.

   | Field        | Value                |
   | ------------ | -------------------- |
   | Project name | Responses            |
   | Location     | $TargetPath\src\Core |

4. On the **Additional information** dialog, ensure the `.NET 8.0 (Long Term Support)` is selected and click the **Create** button.

5. Delete the **Class1.cs** file.

6. Add a reference to the **JSONHelpers** project.

7. Double-click the **Responses** project to open the Responses.csproj file.

8. Add the `<RootNamespace>Remanufacturing</RootNamespace>` to the `PropertyGroup`. Your csproj file should look similar to:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
   
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <ImplicitUsings>enable</ImplicitUsings>
       <Nullable>enable</Nullable>
       <RootNamespace>Remanufacturing</RootNamespace>
     </PropertyGroup>
   
     <ItemGroup>
       <ProjectReference Include="..\JSONHelpers\JSONHelpers.csproj" />
     </ItemGroup>
   
   </Project>
   ```

9. Right-click the **Responses** project and click **Add** > **New folder**; name the folder Responses.

10. Right-click the **Responses** folder and click **Add > Class**; name the class **ResponseType.cs**; and click the **Add** button. Replace the default text with:

    ```c#
    namespace Remanufacturing.Responses;
    
    public enum ResponseType
    {
    	ProblemDetails,
    	StandardResponse,
    	Response
    }
    ```

    

11. Right-click the **Responses** folder and click **Add** > **New Item**; select Interface; name the interface **IResponse.cs**; and click the **Add** button. Replace the default text with:

   ```c#
   using System.Net;
   
   namespace Remanufacturing.Responses;
   
   /// <summary>
   /// Represents a response object based off of the RFC 9457 specification.
   /// </summary>
   public interface IResponse
   {
   
   	/// <summary>
   	/// The type of response being represented.
   	/// </summary>
   	ResponseType ResponseType { get; set; }
   
   	/// <summary>
   	/// A URI reference that identifies the response type. This specification encourages that, when dereferenced, it provide human-readable documentation for the response type.
   	/// </summary>
   	string Type { get; set; }
   
   	/// <summary>
   	/// A short, human-readable summary of the response. It SHOULD NOT change from occurrence to occurrence of the response type, except for purposes of localization.
   	/// </summary>
   	string Title { get; set; }
   
   	/// <summary>
   	/// The HTTP status code for the response.
   	/// </summary>
   	HttpStatusCode Status { get; set; }
   
   	/// <summary>
   	/// A human-readable explanation specific to this occurrence of the response.
   	/// </summary>
   	string? Detail { get; set; }
   
   	/// <summary>
   	/// A URI reference that identifies the specific occurrence of the response. It may or may not yield further information if dereferenced.
   	/// </summary>
   	string? Instance { get; set; }
   
   	/// <summary>
   	/// Additional details about the response that may be helpful when receiving the response.
   	/// </summary>
   	Dictionary<string, object>? Extensions { get; set; }
   
   }
   ```

11. Right-click the **Responses** folder and click **Add** > **Class...**; name the class **ProblemDetail.cs**, and click the **Add** button. Replace the default text with:

    ```c#
    using System.Net;
    
    namespace Remanufacturing.Responses;
    
    /// <summary>
    /// Represents the details of a HTTP problem or error based off of RFC 7807.
    /// </summary>
    public class ProblemDetails : IResponse
    {
    
    	/// <summary>
    	/// The type of response being represented.
    	/// </summary>
    	public ResponseType ResponseType { get; set; } = ResponseType.ProblemDetails;
    
    	/// <summary>
    	/// A URI reference that identifies the problem type. This specification encourages that, when dereferenced, it provide human-readable documentation for the problem type.
    	/// </summary>
    	public string Type { get; set; } = null!;
    
    	/// <summary>
    	/// A short, human-readable summary of the problem type. It SHOULD NOT change from occurrence to occurrence of the problem, except for purposes of localization.
    	/// </summary>
    	public string Title { get; set; } = null!;
    
    	/// <summary>
    	/// The HTTP status code generated by the origin server for this occurrence of the problem.
    	/// </summary>
    	public HttpStatusCode Status { get; set; }
    
    	/// <summary>
    	/// A human-readable explanation specific to this occurrence of the problem.
    	/// </summary>
    	public string? Detail { get; set; }
    
    	/// <summary>
    	/// A URI reference that identifies the specific occurrence of the problem. It may or may not yield further information if dereferenced.
    	/// </summary>
    	public string? Instance { get; set; }
    
    	/// <summary>
    	/// Additional details about the problem that may be helpful when debugging the problem.
    	/// </summary>
    	public Dictionary<string, object>? Extensions { get; set; } = new Dictionary<string, object> { { "traceId", Guid.NewGuid() } };
    
    	public ProblemDetails() { }
    
    	public ProblemDetails(ArgumentException exception, string? instance = null)
    	{
    		Type = "https://example.net/validation-error"; // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
    		Title = "One or more validation errors occurred.";
    		Status = HttpStatusCode.BadRequest;
    		Detail = exception.Message;
    		Instance = instance;
    		if (exception.ParamName != null)
    			Extensions = new Dictionary<string, object>
    			{
    				{ "traceId", Guid.NewGuid() },
    				{ "errors", new Dictionary<string, string[]> { { exception.ParamName, new[] { exception.Message } } } }
    		};
    	}
    
    }
    ```

12. Right-click the **Responses** folder and click **Add** > **Class...**; name the class **StandardRepsonse.cs**, and click the **Add** button. Replace the default text with:

    ```c#
    using System.Net;
    
    namespace Remanufacturing.Responses;
    
    /// <summary>
    /// Represents the standard response for an HTTP endpoint derived from RFC 7807.
    /// </summary>
    public class StandardResponse : IResponse
    {
    
    	/// <summary>
    	/// The type of response being represented.
    	/// </summary>
    	public ResponseType ResponseType { get; set; } = ResponseType.StandardResponse;
    
    	/// <summary>
    	/// A URI reference that identifies the response type. This specification encourages that, when dereferenced, it provide human-readable documentation for the response type.
    	/// </summary>
    	public string Type { get; set; } = null!;
    
    	/// <summary>
    	/// A short, human-readable summary of the response. It SHOULD NOT change from occurrence to occurrence of the response type, except for localization purposes.
    	/// </summary>
    	public string Title { get; set; } = null!;
    
    	/// <summary>
    	/// The HTTP status code for the response.
    	/// </summary>
    	public HttpStatusCode Status { get; set; } = HttpStatusCode.OK;
    
    	/// <summary>
    	/// A human-readable explanation specific to this occurrence of the response.
    	/// </summary>
    	public string? Detail { get; set; }
    
    	/// <summary>
    	/// A URI reference that identifies the specific occurrence of the response. It may or may not yield further information if dereferenced.
    	/// </summary>
    	public string? Instance { get; set; }
    
    	/// <summary>
    	/// Additional details about the response that may be helpful when receiving the response.
    	/// </summary>
    	public Dictionary<string, object>? Extensions { get; set; }
    
    }
    ```

13. Right-click the **Responses** folder and click **Add** > **Class...**; name the class **Response.cs**, and click the **Add** button. Replace the default text with:

    ```c#
    #nullable disable
    
    using System.Net;
    
    namespace Remanufacturing.Responses;
    
    internal class Response : IResponse
    {
    	public ResponseType ResponseType { get; set; } = ResponseType.Response;
    	public string Type { get; set; }
    	public string Title { get; set; }
    	public HttpStatusCode Status { get; set; }
    	public string? Detail { get; set; }
    	public string? Instance { get; set; }
    	public Dictionary<string, object>? Extensions { get; set; }
    }
    ```

    > [!NOTE]
    >
    > The **Response** class is only used by the upcoming **ToResponse** extension method as it needs a concrete object to deserialize text to. Because of this, we have not documented the class, and it is scoped as *internal*.

14. Right-click the **Responses** project and click **Add** > **New folder**; name the folder Extensions.

15. Right-click the **Extensions** folder and click **Add** > **Class...**; name the class **ResponseExtensions.cs**, and click the **Add** button. Replace the default text with:

    ```C#
    using Remanufacturing.Helpers;
    using Remanufacturing.Responses;
    using System.Text.Json;
    
    namespace Remanufacturing.Extensions;
    
    public static class ResponseExtensions
    {
    
    	public static IResponse? ToResponse(this string serializedResponse)
    	{
    
    		JsonSerializerOptions options = new();
    		options.Converters.Add(new InterfaceConverter<IResponse, Response>());
    		IResponse? deserializedResponse = JsonSerializer.Deserialize<IResponse>(serializedResponse, options);
    
    		if (deserializedResponse == null)
    			return null;
    		else if (deserializedResponse.ResponseType == ResponseType.StandardResponse)
    			return JsonSerializer.Deserialize<StandardResponse>(serializedResponse, options);
    		else if (deserializedResponse.ResponseType == ResponseType.ProblemDetails)
    			return JsonSerializer.Deserialize<ProblemDetails>(serializedResponse, options);
    		else
    			return null;
    
    	}
    
    }
    ```

    

### Section 4: Create the Service Bus Helper

Messages to the Service Bus will be sent from multiple components within the Remanufacturing system. Instead of writing the logic to send those messages repeatedly, we will write a Service Bus helper class library to handle these operations.

1. Right-click the **Core** solution folder and click **Add** > **New Project**.

2. Search for and select *Class Library* and click the **Next** button.

3. In the **Configure your new project** dialog, provide the following values and then click the **Next** button.

   | Field        | Value                |
   | ------------ | -------------------- |
   | Project name | ServiceBusHelper     |
   | Location     | $TargetPath\src\Core |

4. On the **Additional information** dialog, ensure the `.NET 8.0 (Long Term Support)` is selected and click the **Create** button.

5. Delete the **Class1.cs** file.

6. Add the following NuGet package references:

   - Azure.Identity
   - Azure.Messaging.ServiceBus

7. Double-click the **ServiceBusHelper** project to open the ServiceBusHelper.csproj file.

8. Add the `<RootNamespace>Remanufacturing</RootNamespace>` to the `PropertyGroup`. Your csproj file should look similar to:

   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
   
     <PropertyGroup>
       <TargetFramework>net8.0</TargetFramework>
       <ImplicitUsings>enable</ImplicitUsings>
       <Nullable>enable</Nullable>
       <RootNamespace>Remanufacturing</RootNamespace>
     </PropertyGroup>
   
     <ItemGroup>
       <PackageReference Include="Azure.Identity" Version="1.12.0" />
       <PackageReference Include="Azure.Messaging.ServiceBus" Version="7.18.0" />
     </ItemGroup>
   
   </Project>
   ```

9. Right-click the **ServiceBusHelper** project and click **Add** > **New folder**; name the folder Exceptions.

10. Right-click the **Responses** folder and click **Add** > **Class...**; name the class **MessageTooLargeForBatchException.cs**, and click the **Add** button. Replace the default text with:

    ```c#
    namespace Remanufacturing.Exceptions;
    
    public class MessageTooLargeForBatchException : Exception
    {
    	public MessageTooLargeForBatchException() : base("One of the messages is too large to fit in the batch.") { }
    	public MessageTooLargeForBatchException(int messageIndex) : base($"The message {messageIndex} is too large to fit in the batch.") { }
    	public MessageTooLargeForBatchException(string message) : base(message) { }
    	public MessageTooLargeForBatchException(string message, Exception innerException) : base(message, innerException) { }
    }
    ```

11. Right-click the **ServiceBusHelper** project and click **Add** > **New folder**; name the folder Services.

12. Right-click the **Services** folder and click **Add** > **Class...**; name the class **ServiceBusServices.cs**, and click the **Add** button. Replace the default text with:

    ```c#
    using Azure.Messaging.ServiceBus;
    using Remanufacturing.Exceptions;
    using System.Text;
    using System.Text.Json;
    
    namespace Remanufacturing.Services;
    
    /// <summary>
    /// Helper methods for sending messages to a Service Bus topic.
    /// </summary>
    public class ServiceBusServices
    {
    
    	/// <summary>
    	/// Sends a single message to a Service Bus topic.
    	/// </summary>
    	/// <typeparam name="T">The type of the message value.</typeparam>
    	/// <param name="serviceBusClient">The Service Bus client.</param>
    	/// <param name="topicName">The name of the topic.</param>
    	/// <param name="value">The value to be serialized into a message to be sent to the Service Bus topic.</param>
    	public static async Task SendMessageAsync<T>(ServiceBusClient serviceBusClient, string topicName, T value)
    	{
    		ServiceBusSender sender = serviceBusClient.CreateSender(topicName);
    		ServiceBusMessage serviceBusMessage = new(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(value)));
    		await sender.SendMessageAsync(serviceBusMessage);
    	}
    
    	/// <summary>
    	/// Sends a batch of messages to a Service Bus topic.
    	/// </summary>
    	/// <typeparam name="T">The type of the message values.</typeparam>
    	/// <param name="serviceBusClient">The Service Bus client.</param>
    	/// <param name="topicName">The name of the topic.</param>
    	/// <param name="values">The Collection of message values to be serialized into message to be sent to the Service Bus topic.</param>
    	/// <exception cref="MessageTooLargeForBatchException">Thrown when a message is too large to fit in the batch.</exception>
    	public static async Task SendMessageBatchAsync<T>(ServiceBusClient serviceBusClient, string topicName, IEnumerable<T> values)
    	{
    		await using ServiceBusSender sender = serviceBusClient.CreateSender(topicName);
    		using ServiceBusMessageBatch messageBatch = await sender.CreateMessageBatchAsync();
    		for (int i = 0; i < values.Count(); i++)
    		{
    			string message = JsonSerializer.Serialize<T>(values.ElementAt(i));
    			if (!messageBatch.TryAddMessage(new ServiceBusMessage(message)))
    				throw new MessageTooLargeForBatchException(i);
    		}
    		await sender.SendMessagesAsync(messageBatch);
    	}
    
    }
    ```

### Section 5: Create the Get Next Core Services Library

In the next part, we will create HTTP-triggered Azure Functions. A good practice is to build class libraries that contain the bulk of the logic implemented by the Azure Functions and then make the Azure Functions very lightweight. The primary reason for doing this is to improve testing capabilities.

> Note that we will not implement unit testing during the workshop, but in a real-world application, we would want good code coverage from our unit tests.

1. Right-click the **Get Next Core** solution folder and click **Add** > **New Project**.

2. Search for and select *Class Library* and click the **Next** button.

3. In the **Configure your new project** dialog, provide the following values and then click the **Next** button.

   | Field        | Value                       |
   | ------------ | --------------------------- |
   | Project name | GetNextCore.Services        |
   | Location     | $TargetPath\src\GetNextCore |

4. On the **Additional information** dialog, ensure the `.NET 8.0 (Long Term Support)` is selected and click the **Create** button.

5. Delete the **Class1.cs** file.

6. Add the following project references:

   - Messages
   - Responses
   - ServiceBusHelper

7. Double-click the **GetNextCore.Services** project to open the GetNextCore.Services.csproj file.

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
       <ProjectReference Include="..\..\Core\Messages\Messages.csproj" />
       <ProjectReference Include="..\..\Core\Responses\Responses.csproj" />
       <ProjectReference Include="..\..\Core\ServiceBusHelper\ServiceBusHelper.csproj" />
     </ItemGroup>
   
   </Project>
   ```

9. Right-click the **ServiceBusHelper** project and click **Add** > **New folder**; name the folder `Services`.

10. Right-click the **Services** folder and click **Add** > **Class...**; name the class **GetNextCoreServiceOptions.cs**, and click the **Add** button. Replace the default text with:

    ```c#
    using Azure.Messaging.ServiceBus;
    
    namespace Remanufacturing.OrderNextCore.Services;
    
    public class GetNextCoreServicesOptions
    {
    	public ServiceBusClient ServiceBusClient { get; set; } = null!;
    	public string GetNextCoreTopicName { get; set; } = null!;
    }
    ```

11. Right-click the **Services** folder and click **Add** > **Class...**; name the class **GetNextCoreServices.cs**, and click the **Add** button. Replace the default text with:

    ```c#
    using Remanufacturing.Messages;
    using Remanufacturing.Responses;
    using Remanufacturing.Services;
    using System.Net;
    
    namespace Remanufacturing.OrderNextCore.Services;
    
    public class GetNextCoreServices(GetNextCoreServicesOptions options)
    {
    
    	private readonly GetNextCoreServicesOptions _servicesOptions = options;
    
    	public async Task<IResponse> RequestNextCoreInformationAsync(OrderNextCoreMessage orderNextCoreMessage, string instance)
    	{
    		try
    		{
    			ArgumentException.ThrowIfNullOrEmpty(orderNextCoreMessage.PodId, nameof(orderNextCoreMessage.PodId));
    			if (orderNextCoreMessage.RequestDateTime == default)
    				orderNextCoreMessage.RequestDateTime = DateTime.UtcNow;
    			await ServiceBusServices.SendMessageAsync(_servicesOptions.ServiceBusClient, _servicesOptions.GetNextCoreTopicName, orderNextCoreMessage);
    			return new StandardResponse()
    			{
    				Type = "https://httpstatuses.com/201", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
    				Title = "Request for next core id sent.",
    				Status = HttpStatusCode.Created,
    				Detail = "The request for the next core id has been sent to the Production Schedule.",
    				Instance = instance,
    				Extensions = new Dictionary<string, object>()
    				{
    					{ "PodId", orderNextCoreMessage.PodId },
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
    
    }
    ```

### Section 6: Create the Get Next Core Azure Function

There are several ways to implement serverless REST endpoints. For the Remanufacturing system, we will use HTTP-triggered Azure Functions. These offer an easy programming interface and exceptional scalability capability.

1. Right-click the **Get Next Core** solution folder and click **Add** > **New Project**.

2. Search for and select *Azure Functions* and click the **Next** button.

3. In the **Configure your new project** dialog, provide the following values and then click the **Next** button.

   | Field        | Value                       |
   | ------------ | --------------------------- |
   | Project name | GetNextCore.Functions       |
   | Location     | $TargetPath\src\GetNextCore |

4. On the **Additional information dialog**, provide the following values/settings and click the **Create** button:

   | Field                                                        | Value                                 |
   | ------------------------------------------------------------ | ------------------------------------- |
   | Functions worker                                             | .NET 8.0 Isolated (Long Term Support) |
   | Function                                                     | Http trigger                          |
   | Use Azureite for runtime storage account (AzureWebJobsStorage) | checked                               |
   | Enable container support                                     | unchecked                             |
   | Authorization level                                          | unction                               |

5. Delete the **Function1.cs** file.

6. Add a project reference to the **GetNextCore.Services** project.

7. Double-click the **GetNextCore.Functions** project to open the GetNextCore.Functions.csproj file.

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
       <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.4" />
       <PackageReference Include="Microsoft.ApplicationInsights.WorkerService" Version="2.22.0" />
       <PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="1.2.0" />
     </ItemGroup>
     <ItemGroup>
       <ProjectReference Include="..\GetNextCore.Services\GetNextCore.Services.csproj" />
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

9. Replace the default **Program.cs** content with:

   ```c#
   using Azure.Messaging.ServiceBus;
   using Microsoft.Azure.Functions.Worker;
   using Microsoft.Extensions.DependencyInjection;
   using Microsoft.Extensions.Hosting;
   using Remanufacturing.OrderNextCore.Services;
   
   GetNextCoreServicesOptions getNextCoreServicesOptions = new()
   {
   	ServiceBusClient = new ServiceBusClient(Environment.GetEnvironmentVariable("ServiceBusConnectionString")!),
   	GetNextCoreTopicName = Environment.GetEnvironmentVariable("GetNextCoreTopicName")!,
   };
   
   IHost host = new HostBuilder()
   	.ConfigureFunctionsWebApplication()
   	.ConfigureServices(services =>
   	{
   		services.AddApplicationInsightsTelemetryWorkerService();
   		services.ConfigureFunctionsApplicationInsights();
   		services.AddHttpClient();
   		services.AddSingleton(new GetNextCoreServices(getNextCoreServicesOptions));
   	})
   	.Build();
   
   host.Run();
   ```

10. Right-click the **GetNextCore.Functions** project and click **Add** > **New folder**; name the folder Functions.

11. Right-click the **Responses** folder and click **Add** > **New Azure Function...**; name the class **GetNextCore.cs**, and click the **Add** button. Select `Http trigger`. Replace the default text with:

    ```c#
    using Microsoft.AspNetCore.Http;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Azure.Functions.Worker;
    using Microsoft.Extensions.Logging;
    using Remanufacturing.Messages;
    using Remanufacturing.OrderNextCore.Services;
    using Remanufacturing.Responses;
    using System.Text.Json;
    
    namespace Remanufacturing.OrderNextCore.Functions;
    
    public class GetNextCore(ILogger<GetNextCore> logger, GetNextCoreServices getNextCoreServices)
    {
    
    	private readonly ILogger<GetNextCore> _logger = logger;
    	private readonly GetNextCoreServices _getNextCoreServices = getNextCoreServices;
    
    	[Function("GetNextCore")]
    	public async Task<IActionResult> RunAsync([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequest request)
    	{
    		string requestBody = await new StreamReader(request.Body).ReadToEndAsync();
    		OrderNextCoreMessage? nextCoreRequestMessage = JsonSerializer.Deserialize<OrderNextCoreMessage>(requestBody);
    		if (nextCoreRequestMessage is not null)
    		{
    			_logger.LogInformation("Get next core for Pod '{podId}'", nextCoreRequestMessage.PodId);
    			IResponse response = await _getNextCoreServices.RequestNextCoreInformationAsync(nextCoreRequestMessage, request.HttpContext.TraceIdentifier);
    			return new ObjectResult(response) { StatusCode = (int)response.Status };
    		}
    		else
    		{
    			_logger.LogWarning("Invalid request body.");
    			return new BadRequestObjectResult("Invalid request body.");
    		}
    	}
    
    }
    ```

12. Retrieve the Service Bus connection string by:

    1. From the [Azure Portal](htttps://portal.azure.com), search for `sbns-CoolRevive` and select the Service Bus Namespace during [Lab 0](00-initialize-environment.md).
    2. Click on **Settings** > **Shared access policies**.
    3. Click on **RootManageSharedAccessKey**.
    4. Make note of the Primary Connection String.

13. Get the name of the **Get Next Core** topic by:

    1. Click on **Entities** > **Topics**.
    2. Make note of the full name of the **sbt-coolrevive-getnextcore** service bus topic.

14. Add the environment secrets to the Azure Function project by:

    1. Open the local.settings.json file
    2. Add a **ServiceBusConnectionString** key with the primary connection string you made of note of before.
    3. Add a **GetNextCoreTopicName** key with the full name of the **sbt-coolrevive-getnextcore** service bus topic.

    Your local.settings.json file should look similar to:

    ```json
    {
      "IsEncrypted": false,
      "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
        "ServiceBusConnectionString": "Endpoint=sb://sbns-remanufacturing329-dev-use2.servicebus.windows.net/;SharedAccessKeyName=GetNextCoreSender;SharedAccessKey=xxxx=",
        "GetNextCoreTopicName": "sbt-getnextcore329-dev-use2"
      }
    }
    ```

### Section 7: Test the Azure Function locally

1. Right-click the `GetNextCore.Functions` project and select **Set as Startup Project**.

2. Press **F5** to start the Azure Function app locally.

3. Copy the **GetNextCore** endpoint.

4. Open Postman and enter the **GetNextCore** in the **Enter URL or paste text** field.

5. Change the HTTP method to **POST**.

6. Go the **Body** tab.

7. Select **raw**.

8. Paste the following into the request body field:

   ```json
   {
       "MessageId": "message-123",
       "MessageType": "GetNextCore",
       "PodId": "Pod123"
   }
   ```

9. Click the **Send** button. You should receive a **201 Created** response with a response body similar to:

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

10. Back in the [Azure Portal](https://portal.azure.com), click the **Service Bus Explorer** menu item (assuming you are still in the `sbt-getnextcore` topic from before).

11. Select the `sbts-GetNextCore` subscription and then click **Peak from start** button. You should see the message just sent to the Service Bus topic.

## Conclusion

In this lab, you have created the first step of the Order Next Core process, which consists of an HTTP-triggered Azure Function that, after some processing, sends a message to the Service Bus indicating that information about the next core to be remanufactured by the pod is needed.

## Next Steps

In the next lab, you will mock the Production Schedule endpoints needed to retrieve the core information.