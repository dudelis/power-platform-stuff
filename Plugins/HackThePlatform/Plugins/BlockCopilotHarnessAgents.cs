using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;

namespace Plugins
{
    public class BlockCopilotHarnessAgents : IPlugin
    {
        private const string BotTableName = "bot";
        private const string ProcessTableName = "workflow";
        private const string ConfigurationColumnName = "configuration";
        private const string HarnessRecognizerKind = "CLICopilotRecognizer";

        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracing = (ITracingService)serviceProvider.GetService(typeof(ITracingService));

            if (!context.MessageName.Equals("Create", StringComparison.OrdinalIgnoreCase) &&
                !context.MessageName.Equals("Update", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            var target = context.InputParameters.Contains("Target")
                ? context.InputParameters["Target"] as Entity
                : null;

            if (target == null)
            {
                return;
            }

            if (context.PrimaryEntityName.Equals(BotTableName, StringComparison.OrdinalIgnoreCase))
            {
                ValidateBot(serviceProvider, context, target, tracing);
                return;
            }

            if (context.PrimaryEntityName.Equals(ProcessTableName, StringComparison.OrdinalIgnoreCase))
            {
                tracing.Trace("Process validation is not implemented yet (TBD).");
            }
        }

        private static void ValidateBot(
            IServiceProvider serviceProvider,
            IPluginExecutionContext context,
            Entity target,
            ITracingService tracing)
        {
            string configuration = GetConfiguration(serviceProvider, context, target);
            if (string.IsNullOrWhiteSpace(configuration))
            {
                return;
            }

            JObject configurationJson;
            try
            {
                configurationJson = JObject.Parse(configuration);
            }
            catch (JsonReaderException exception)
            {
                tracing.Trace("The bot configuration is not valid JSON: {0}", exception.Message);
                return;
            }

            string recognizerKind = configurationJson["recognizer"]?["$kind"]?.Value<string>();
            if (string.Equals(recognizerKind, HarnessRecognizerKind, StringComparison.Ordinal))
            {
                throw new InvalidPluginExecutionException(
                    "GitHub Copilot Harness agents cannot be created or edited in this environment."
                );
            }
        }

        private static string GetConfiguration(
            IServiceProvider serviceProvider,
            IPluginExecutionContext context,
            Entity target)
        {
            if (target.Attributes.Contains(ConfigurationColumnName))
            {
                return target.GetAttributeValue<string>(ConfigurationColumnName);
            }

            foreach (var image in context.PreEntityImages.Values)
            {
                if (image.Attributes.Contains(ConfigurationColumnName))
                {
                    return image.GetAttributeValue<string>(ConfigurationColumnName);
                }
            }

            if (!context.MessageName.Equals("Update", StringComparison.OrdinalIgnoreCase) ||
                target.Id == Guid.Empty)
            {
                return null;
            }

            var serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(
                typeof(IOrganizationServiceFactory)
            );
            var service = serviceFactory.CreateOrganizationService(context.UserId);
            var existingBot = service.Retrieve(
                BotTableName,
                target.Id,
                new ColumnSet(ConfigurationColumnName)
            );

            return existingBot.GetAttributeValue<string>(ConfigurationColumnName);
        }
    }
}