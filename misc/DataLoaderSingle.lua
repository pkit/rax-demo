--[[
Same as DataLoader but only requires a folder of images. 
Does not have an h5 dependency.
Only used at test time.
]]--

local utils = require 'misc.utils'
require 'lfs'
require 'image'

local DataLoaderSingle = torch.class('DataLoaderSingle')

function DataLoaderSingle:__init(opt)

  self.files = {}
  self.ids = {}
--  print('loading image from ' .. opt.image_path)
  
  local function isImage(f)
    local supportedExt = {'.jpg','.JPEG','.JPG','.png','.PNG','.ppm','.PPM'}
    for _,ext in pairs(supportedExt) do
      local _, end_idx =  f:find(ext)
      if end_idx and end_idx == f:len() then
        return true
      end
    end
    return false
  end
  
  if isImage(opt.image_path) then
    table.insert(self.files, opt.image_path)
    table.insert(self.ids, 1)
  end

  self.N = #self.files
  assert(self.N > 0, 'image_path ' .. opt.image_path .. ' is not an image!')

  self.iterator = 1
end

function DataLoaderSingle:resetIterator()
  self.iterator = 1
end

--[[
  Returns a batch of data:
  - X (N,3,256,256) containing the images as uint8 ByteTensor
  - info table of length N, containing additional information
  The data is iterated linearly in order
--]]
function DataLoaderSingle:getBatch(opt)
  local batch_size = utils.getopt(opt, 'batch_size', 5) -- how many images get returned at one time (to go through CNN)
  -- pick an index of the datapoint to load next
  local img_batch_raw = torch.ByteTensor(batch_size, 3, 256, 256)
  local max_index = self.N
  local wrapped = false
  local infos = {}
  for i=1,batch_size do
    local ri = self.iterator
    local ri_next = ri + 1 -- increment iterator
    if ri_next > max_index then ri_next = 1; wrapped = true end -- wrap back around
    self.iterator = ri_next

    -- load the image
    local img = image.load(self.files[ri], 3, 'byte')
    img_batch_raw[i] = image.scale(img, 256, 256)

    -- and record associated info as well
    local info_struct = {}
    info_struct.id = self.ids[ri]
    info_struct.file_path = self.files[ri]
    table.insert(infos, info_struct)
  end

  local data = {}
  data.images = img_batch_raw
  data.bounds = {it_pos_now = self.iterator, it_max = self.N, wrapped = wrapped}
  data.infos = infos
  return data
end

