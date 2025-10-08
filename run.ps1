using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$jsonOnly = $Request.Query.jsonOnly # use as https://ps-fn-app-demo.azurewebsites.net/api/http-trigger-ps-fn?jsonOnly=false&&code=...

#Define api url
$nasaApiUrl = "https://api.nasa.gov/mars-photos/api/v1/rovers/curiosity/photos?sol=1000&api_key=IoCUJVCdemHilgLfk0lv40961uQp4Hnl1fKrhSWD"

try {
  # Ensures that Invoke-WebRequest uses TLS 1.2
  [ Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  # Capture API response
  $apiResponse = Invoke-RestMethod -Uri $nasaApiUrl -Method Get
  #  query parameter logic
  if (-not $jsonOnly) {
    $random = Get-Random -Minimum 0 -Maximum $apiResponse.photos.Count
    $randomPhoto = $apiResponse.photos[$random]  
    $body += "<html><body style='text-align: center;'><H1>Random Marth Photo</H1><br>"
    $body += "<img src='" + $randomPhoto.img_src + "' style='width: 750px; height: auto;'></img><br><hr></body></html>"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
     StatusCode  = [HttpStatusCode]::OK
     ContentType = "text/html" # <-- Set content type to HTML to render in browser
     Body        = $body
    })
  } 
  else {
    $body += $apiResponse | ConvertTo-Json 
    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
      StatusCode = [HttpStatusCode]::OK
      Body = $body # Return JSON response
    })
  }
} catch {
    # Handle any errors during the API call
    $errorMessage = $_.Exception.Message
    Write-Error "Error calling API: $errorMessage"
    $statusCode = 500
    $body = @{ error = $errorMessage } | ConvertTo-Json
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
      StatusCode = $statusCode # Return HTTP 500 for server errors
      Body = $body
    })
}

