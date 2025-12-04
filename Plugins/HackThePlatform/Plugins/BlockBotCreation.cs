using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Plugins
{
    public class BlockBotCreation : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            throw new InvalidPluginExecutionException(
                "Copilot Agents creation is not allowed in the Default environment."
            );
        }
    }
}
