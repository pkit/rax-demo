## Caption API

Send POST request to `http://hostname:8888/caption`

The body should be the raw image data.  
The header `Content-Type` should be properly set.  
Currently supported types are: `image/jpeg`, `image/png`  

The responses are:

200: OK  
headers: `Content-Type: application/json`  
body: `{"caption": "some caption", "elapsed":100.11}`  
where `elapsed` is the time in ms to serve the caption

400: Problem with your request, probably no content-type set or unsupported content type

500: Server error

