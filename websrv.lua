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

local app = turbo.web.Application:new({
    {"/caption", CaptionHandler}
})

app:listen(8888)
turbo.ioloop.instance():start()

