require 'socket'
require 'torch'
require 'nn'
require 'nngraph'
-- exotics
require 'loadcaffe'
-- local imports
package.path = package.path .. ";../neuraltalk2/?.lua"
local utils = require 'misc.utils'
require 'misc.DataLoaderSingle'
require 'misc.LanguageModel'
local net_utils = require 'misc.net_utils'

local Caption = torch.class('Caption')

function Caption:__init(args)
    local opt = {
        model = args.model,
        batch_size = 1,
        num_images = 1,
        language_eval = 0,
        dump_images = 0,
        dump_json = 0,
        dump_path = 0,
        sample_max = 1,
        beam_size = 2,
        temperature = 1.0,
        image_folder = '',
        image_root = '',
        image_path = '',
        input_h5 = '',
        input_json = '',
        split = 'test',
        coco_json = '',
        backend = 'cudnn',
        id = 'evalscript',
        seed = 123,
        gpuid = 0
    }

    torch.setdefaulttensortype('torch.FloatTensor')
    -- cuda stuff
    require 'cutorch'
    require 'cunn'
    require 'cudnn'
    cutorch.setDevice(opt.gpuid + 1) -- note +1 because lua is 1-indexed

    self.checkpoint = torch.load(opt.model)
    opt.input_h5 = self.checkpoint.opt.input_h5
    opt.input_json = self.checkpoint.opt.input_json
    local fetch = {'rnn_size', 'input_encoding_size', 'drop_prob_lm', 'cnn_proto', 'cnn_model', 'seq_per_img'}
    for k,v in pairs(fetch) do
        opt[v] = self.checkpoint.opt[v] -- copy over options from model
    end
    self.vocab = self.checkpoint.vocab -- ix -> word mapping

    -------------------------------------------------------------------------------
    -- Load the networks from model checkpoint
    -------------------------------------------------------------------------------
    self.protos = self.checkpoint.protos
    self.protos.expander = nn.FeatExpander(opt.seq_per_img)
    self.protos.crit = nn.LanguageModelCriterion()
    self.protos.lm:createClones() -- reconstruct clones inside the language model
    if opt.gpuid >= 0 then
        for k,v in pairs(self.protos) do v:cuda() end
    end
end


function Caption:get_caption(image_path)
    -------------------------------------------------------------------------------
    -- Evaluation fun(ction)
    -------------------------------------------------------------------------------
    local t = socket.gettime()
    self.protos.cnn:evaluate()
    self.protos.lm:evaluate()

    local loader = DataLoaderSingle{image_path = image_path}
    loader:resetIterator(split) -- rewind iteator back to first datapoint in the split

    -- fetch a batch of data
    local data = loader:getBatch{batch_size = 1, split = 'test'}
    data.images = net_utils.prepro(data.images, false, true) -- preprocess in place, and don't augment

    -- forward the model to get loss
    local feats = self.protos.cnn:forward(data.images)

    -- forward the model to also get generated samples for each image
    local sample_opts = { sample_max = 1, beam_size = 2, temperature = 1.0 }
    local seq = self.protos.lm:sample(feats, sample_opts)
    local sents = net_utils.decode_sequence(self.vocab, seq)
    local entry = {image_id = data.infos[1].id, caption = sents[1]}
    return {caption = entry.caption, elapsed = (socket.gettime() - t)*1000}
end
