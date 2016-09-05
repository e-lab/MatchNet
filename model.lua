-- Eugenio Culurciello
-- August 2016
-- MatchNet: a model of PredNet from: https://arxiv.org/abs/1605.08104
-- Chainer implementation conversion based on: https://github.com/quadjr/PredNet/blob/master/net.py

require 'nn'
require 'nngraph'

torch.setdefaulttensortype('torch.FloatTensor')
nngraph.setDebug(true)

-- one layer, not time dependency:
local insize = 64
local input_stride = 1
local poolsize = 2
local mapss = {3, 32, 64, 128, 256} -- layer maps sizes

local layer={}
-- P = prediction branch, A_hat in paper

local nlayers = 1

-- This module creates the MatchNet network model, defined as:
-- inputs = {prevE, nextR}
-- outputs = {E , R}, E == discriminator output, R == generator output

-- creating input and output lists:
local inputs = {}
local outputs = {}
table.insert(inputs, nn.Identity()()) -- insert model input / image
for L = 1, nlayers do
   -- input: {input, pE, tE, nR, ...}
   inputs[3*L-2] =  nn.Identity()() -- previous E
   inputs[3*L-1] = nn.Identity()() -- this E
   inputs[3*L] = nn.Identity()() -- next R
   -- output has to be defined for upper layer values to propagate to lowers
   -- outputs[2*L-1] = nn.Identity()() -- this layer E
   -- outputs[2*L] = nn.Identity()() -- this layer R
end

for L = 1, nlayers do
   print('Creating layer:', L)

   -- define layer functions:
   local cA = nn.SpatialConvolution(mapss[L], mapss[L+1], 3, 3, input_stride, input_stride, 1, 1) -- A convolution, maxpooling
   local cR = nn.SpatialConvolution(mapss[L], mapss[L+1], 3, 3, input_stride, input_stride, 1, 1) -- recurrent / convLSTM temp model
   local cP = nn.SpatialConvolution(mapss[L+1], mapss[L+1], 3, 3, input_stride, input_stride, 1, 1) -- P convolution
   local mA = nn.SpatialMaxPooling(poolsize, poolsize, poolsize, poolsize)
   local up = nn.SpatialUpSamplingNearest(poolsize)
   local op = nn.PReLU(mapss[L+1])

   local pE, A, upR, R, P, E

   if L == 1 then
      pE = inputs[1] -- model input (input image)
   else
      pE = outputs[2*L-1] -- previous layer E
   end
   pE:annotate{graphAttributes = {color = 'green', fontcolor = 'green'}}
   A = pE - cA - mA - nn.ReLU()

   if L == nlayers then
      R = inputs[3*L-1] - cR -- this E = inputs[3*L-1] in this layer!
   else
      upR = inputs[3*L] - up -- upsampling of next layer R
      R = {inputs[3*L-1], upR} - nn.CAddTable(1) - cR -- this E = inputs[3*L-1] in this layer!
   end

   P = {R} - cP - nn.ReLU()
   E = {A, P} - nn.CSubTable(1) - op -- PReLU instead of +/-ReLU
   E:annotate{graphAttributes = {color = 'blue', fontcolor = 'blue'}}
   -- set outputs:
   outputs[2*L-1] = E -- this layer E
   outputs[2*L] = R -- this layer R
end

-- create graph
print('Creating model:')
local model = nn.gModule(inputs, outputs)
nngraph.annotateNodes()
graph.dot(model.fg, 'MatchNet','Model') -- graph the model!


-- test:
-- print('Testing model:')
