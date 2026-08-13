public class Script : ScriptBase
{
    public override async Task<HttpResponseMessage> ExecuteAsync()
    {
        var incomingRequest = this.Context.Request;

        // Read the custom header from the connector request - parameter authHeader
        string authHeaderValue = null;
        if (incomingRequest.Headers.Contains("authHeader"))
        {
            authHeaderValue = incomingRequest.Headers
                .GetValues("authHeader")
                .FirstOrDefault();
        }

        // Create outgoing request
        var outgoingRequest = new HttpRequestMessage(
            incomingRequest.Method,
            incomingRequest.RequestUri
        );

        // Copy body if present
        if (incomingRequest.Content != null)
        {
            outgoingRequest.Content = incomingRequest.Content;
        }

        // Copy all headers except authHeader
        foreach (var header in incomingRequest.Headers)
        {
            if (!string.Equals(header.Key, "authHeader", StringComparison.OrdinalIgnoreCase))
            {
                outgoingRequest.Headers.TryAddWithoutValidation(header.Key, header.Value);
            }
        }

        // Set Authorization header from authHeader value
        if (!string.IsNullOrWhiteSpace(authHeaderValue))
        {
            outgoingRequest.Headers.TryAddWithoutValidation("Authorization", authHeaderValue);
        }

        // Forward request
        return await this.Context.SendAsync(outgoingRequest, this.CancellationToken);
    }
}