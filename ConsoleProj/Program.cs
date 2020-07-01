using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using System.Net;
using System.IO;
using System.Linq.Expressions;
using Microsoft.Azure.Documents;
using Microsoft.Azure.Documents.Client;
using Microsoft.Azure.Documents.Linq;
using Newtonsoft.Json;
using System.Configuration;
using Newtonsoft.Json.Linq;
using System.Net.Configuration;

namespace ARMAPI_Test
{


    class Program
    {
       //This is a sample console application that shows you how to grab a token from AAD for the current user of the app, and then get usage data for the customer with that token.
       //The same caveat remains, that the current user of the app needs to be part of either the Owner, Reader or Contributor role for the requested AzureSubID.
        static void Main(string[] args)
        {
            //Get the AAD token to get authorized to make the call to the Usage API
            string token = GetOAuthTokenFromAAD();

            /*Setup API call to Usage API
             Callouts:
             * See the App.config file for all AppSettings key/value pairs
             * You can get a list of offer numbers from this URL: http://azure.microsoft.com/en-us/support/legal/offer-details/
             * See the Azure Usage API specification for more details on the query parameters for this API.
             * The Usage Service/API is currently in preview; please use 2015-06-01-preview for api-version
             * Please see the readme if you are having problems configuring or authenticating: https://github.com/Azure-Samples/billing-dotnet-usage-api
             
            */
            // Build up the HttpWebRequest
            string requestURL = String.Format("{0}/{1}/{2}/{3}",
                       ConfigurationManager.AppSettings["ARMBillingServiceURL"],
                       "subscriptions",
                       ConfigurationManager.AppSettings["SubscriptionID"],
                       "providers/Microsoft.Commerce/UsageAggregates?api-version=2015-06-01-preview&reportedstartTime=2019-12-01+00%3a00%3a00Z&reportedEndTime=2020-05-18+00%3a00%3a00Z");
            string path = System.Environment.CurrentDirectory + "\\usage" + DateTime.Now.ToString("yyyy-MM-dd");


            // Call the Usage API, dump the output to the console window
            try
            {
                // Call the REST endpoint




                // Pipes the stream to a higher level stream reader with the required encoding format. 
                dynamic usagedata = null;

                List<UsagePayload> aggregatedPayload = new List<UsagePayload>();

                do
                {
                    HttpWebRequest request = (HttpWebRequest)WebRequest.Create(requestURL);

                    // Add the OAuth Authorization header, and Content Type header
                    request.Headers.Add(HttpRequestHeader.Authorization, "Bearer " + token);
                    request.ContentType = "application/json";
                    Console.WriteLine("Calling Usage service...");
                    HttpWebResponse response = (HttpWebResponse)request.GetResponse();
                    Console.WriteLine(String.Format("Usage service response status: {0}", response.StatusDescription));
                    Stream receiveStream = response.GetResponseStream();

                    StreamReader readStream = new StreamReader(receiveStream, Encoding.UTF8);
                    var usageResponse = readStream.ReadToEnd();
                    usagedata = JObject.Parse(usageResponse);

                    requestURL = usagedata.nextLink;
                    File.WriteAllText(path + ".txt", usageResponse);

                    UsagePayload payload = JsonConvert.DeserializeObject<UsagePayload>(usageResponse);
                    aggregatedPayload.Add(payload);
                    response.Close();
                    readStream.Close();

                } while (usagedata.nextLink != null);

                //File.WriteAllText(path + ".txt", stringBuilder.ToString());
                //Console.WriteLine("Usage stream received.  Press ENTER to continue with raw output.");

                StringBuilder csv = new StringBuilder();
                StringBuilder header = new StringBuilder();
                header.Append("Id;");
                header.Append("AggregateType;");
                header.Append("Location;");
                header.Append("Tags;");
                header.Append("MeterCategory;");
                header.Append("MeterName;");
                header.Append("MeterRegion;");
                header.Append("MetersSubCategory;");
                header.Append("Quantity;");
                header.Append("subscriptionId;");
                header.Append("Unit;");
                header.Append("usageEndTime;");
                header.Append("usageStartTime");

                csv.AppendLine(header.ToString());
                foreach (UsagePayload payload in aggregatedPayload)
                {
                    foreach(UsageAggregate item in payload.value)
                    {
                        StringBuilder record = new StringBuilder();
                        record.Append(item.id);
                        record.Append(";");
                        //record.Append(item.name);
                        //record.Append(";");
                        record.Append(item.type);
                        record.Append(";");
                        //record.Append(item.properties.infoFields.meteredRegion);
                        //record.Append(";");
                        //record.Append(item.properties.infoFields.meteredService);
                        //record.Append(";");
                        //record.Append(item.properties.infoFields.meteredServiceType);
                        //record.Append(";");
                        //record.Append(item.properties.infoFields.project);
                        //record.Append(";");
                        //record.Append(item.properties.infoFields.serviceInfo1);
                        //record.Append(";");
                        //record.Append(item.properties.InstanceData.MicrosoftResources.additionalInfo);
                        //record.Append(";");
                        record.Append(item.properties.InstanceData.MicrosoftResources.location);
                        record.Append(";");
                        //record.Append(item.properties.InstanceData.MicrosoftResources.orderNumber);
                        //record.Append(";");
                        //record.Append(item.properties.InstanceData.MicrosoftResources.partNumber);
                        //record.Append(";");
                        record.Append(item.properties.InstanceData.MicrosoftResources.tags);
                        record.Append(";");
                        record.Append(item.properties.meterCategory);
                        record.Append(";");
                        record.Append(item.properties.meterName);
                        record.Append(";");
                        record.Append(item.properties.meterRegion);
                        record.Append(";");
                        record.Append(item.properties.meterSubCategory);
                        record.Append(";");
                        record.Append(item.properties.quantity);
                        record.Append(";");
                        record.Append(item.properties.subscriptionId);
                        record.Append(";");
                        record.Append(item.properties.unit);
                        record.Append(";");
                        record.Append(item.properties.usageEndTime);
                        record.Append(";");
                        record.Append(item.properties.usageStartTime);
                        csv.AppendLine(record.ToString());
                    }
                }
                File.WriteAllText(path + ".csv", csv.ToString());


                // Convert the Stream to a strongly typed RateCardPayload object.  
                // You can also walk through this object to manipulate the individuals member objects. 

            }
            catch (Exception e)
            {
                Console.WriteLine(String.Format("{0} \n\n{1}", e.Message, e.InnerException != null ? e.InnerException.Message : ""));
                Console.ReadLine();
            }
        }
        public static string GetOAuthTokenFromAAD()
        {
            var authenticationContext = new AuthenticationContext(String.Format("{0}/{1}",
                                                                    ConfigurationManager.AppSettings["ADALServiceURL"],
                                                                    ConfigurationManager.AppSettings["TenantDomain"]));

            //Ask the logged in user to authenticate, so that this client app can get a token on his behalf
            var result = authenticationContext.AcquireToken(String.Format("{0}/", ConfigurationManager.AppSettings["ARMBillingServiceURL"]),
                                                            ConfigurationManager.AppSettings["ClientID"],
                                                            new Uri(ConfigurationManager.AppSettings["ADALRedirectURL"]),
                                                            PromptBehavior.Always);

            if (result == null)
            {
                throw new InvalidOperationException("Failed to obtain the JWT token");
            }

            return result.AccessToken;
        }
  
    }
}
