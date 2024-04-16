using System.Data;
public class Script : ScriptBase
{
    public override async Task<HttpResponseMessage> ExecuteAsync()
    {
        HttpResponseMessage response;
        if (this.Context.OperationId.ToLower() == "convertcsvtojson")
        {
            var contentAsString = await this.Context.Request.Content.ReadAsStringAsync().ConfigureAwait(false);
            var contentAsJson = JObject.Parse(contentAsString);
            var csv = (string)contentAsJson["csvText"];
            var delimeter = (char)contentAsJson["csvDelimeter"];
            string jsonOutput = CsvConverter.ConvertCsvToJson(csv, delimeter);
            response = new HttpResponseMessage(HttpStatusCode.OK);
            response.Content = new StringContent(jsonOutput);
            return response;
        }

        // Handle an invalid operation ID
        response = new HttpResponseMessage(HttpStatusCode.BadRequest);
        response.Content = CreateJsonContent($"Unknown operation ID '{this.Context.OperationId}'");
        return response;
    }

    public class CsvConverter
    {
        public static string ConvertCsvToJson(string csvText, char delimiter)
        {
            string[] lines = csvText.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.RemoveEmptyEntries);
            string[] headers = lines[0].Split(delimiter);

            var jsonArray = new List<Dictionary<string, string>>();

            for (int i = 1; i < lines.Length; i++)
            {
                string[] fields = lines[i].Split(delimiter);
                var jsonObject = new Dictionary<string, string>();

                for (int j = 0; j < headers.Length; j++)
                {
                    if (fields.Length > j)
                        jsonObject[headers[j]] = fields[j];
                    else
                        jsonObject[headers[j]] = string.Empty;
                }
                jsonArray.Add(jsonObject);
            }

            return Newtonsoft.Json.JsonConvert.SerializeObject(jsonArray);
        }
    }
}
