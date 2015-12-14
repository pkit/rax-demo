local turbo = require("turbo")
local cjson = require 'cjson'
require("Caption")

local CaptionHandler = class("CaptionHandler", turbo.web.RequestHandler)
local c = Caption{model = '../model_id1-501-1448236541.t7'}

function CaptionHandler:post()
    local content_type = self.request.headers:get('Content-Type')
    local tmp_file = os.tmpname()
    if content_type == 'image/jpeg' then
        tmp_file = tmp_file .. '.jpg'
    elseif content_type == 'image/png' then
        tmp_file = tmp_file .. '.png'
    else
        error(turbo.web.HTTPError:new(400, "Not supported content type: " .. content_type))
    end
    local fp = io.open(tmp_file, 'w')
    fp:write(self.request.body)
    fp.close()
    self:set_header('Content-Type', 'application/json')
    self:write(cjson.encode(c:get_caption(tmp_file)))
    os.remove(tmp_file)
end

local resp = [[
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Preview images</title>
    <style>
        #gallery .thumbnail{
            width:150px;
            height: 150px;
            float:left;
            margin:2px;
        }
        #gallery .thumbnail img{
            width:150px;
            height: 150px;
        }

    </style>
</head>
<body>
<h2>Upload images ...</h2>

<input type="file" id="fileinput" multiple="multiple" accept="image/*" />

<div id="gallery"></div>
<script>
var uploadfiles = document.querySelector('#fileinput');
uploadfiles.addEventListener('change', function () {
    var files = this.files;
    for(var i=0; i<files.length; i++){
        previewImage(this.files[i]);
    }

}, false);

function previewImage(file) {
    var galleryId = "gallery";

    var gallery = document.getElementById(galleryId);
    var imageType = /image.*/;

    if (!file.type.match(imageType)) {
        throw "File Type must be an image";
    }

    var thumb = document.createElement("div");
    thumb.classList.add('thumbnail'); // Add the class thumbnail to the created div

    var img = document.createElement("img");
    img.file = file;
    thumb.appendChild(img);
    gallery.appendChild(thumb);

    // Using FileReader to display the image content
    var reader = new FileReader();
    reader.onload = (function(aImg) { return function(e) { aImg.src = e.target.result; }; })(img);
    reader.readAsDataURL(file);
    uploadFile(file, thumb);
}

function uploadFile(file, thumb){
    var url = '/caption';
    var xhr = new XMLHttpRequest();
    xhr.open("POST", url, true);
    xhr.setRequestHeader("Content-Type", file.type);
    xhr.onreadystatechange = function() {
        thumb.style.textAlign = "center";
        var caption = document.createElement("span");
        if (xhr.readyState == 4 && xhr.status == 200) {
            console.log(xhr.responseText);
            var resp = JSON.parse(xhr.responseText);
            caption.innerHTML = resp.caption;
        }
        if (xhr.readyState == 4 && xhr.status != 200) {
            caption.innerHTML = "Error: " + xhr.responseText;
        }
        thumb.appendChild(caption);
    };
    xhr.send(file);
}
</script>
</body>
</html>
]]

function CaptionHandler:get()
    self:write(resp)
end

local app = turbo.web.Application:new({
    {"/caption", CaptionHandler}
})

app:listen(8888)
turbo.ioloop.instance():start()

