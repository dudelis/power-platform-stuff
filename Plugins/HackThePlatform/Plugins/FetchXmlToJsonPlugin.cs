using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;

namespace HackThePlatform.Plugins
{
    public class FetchXmlToJsonPlugin : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = serviceFactory.CreateOrganizationService(context.UserId);

            if (!context.InputParameters.Contains("fetchxml") || !(context.InputParameters["fetchxml"] is string))
                throw new InvalidPluginExecutionException("FetchXML input parameter is missing or invalid.");

            string fetchXml = (string)context.InputParameters["fetchxml"];
            var result = service.RetrieveMultiple(new FetchExpression(fetchXml));

            var list = new List<Dictionary<string, object>>();
            foreach (var entity in result.Entities)
            {
                var dict = new Dictionary<string, object>();
                foreach (var attr in entity.Attributes)
                {
                    dict[attr.Key] = attr.Value;
                }
                list.Add(dict);
            }

            string json = JsonConvert.SerializeObject(list, Formatting.None);
            context.OutputParameters["json"] = json;
        }
    }
}
