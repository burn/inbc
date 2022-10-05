g=require"glua"

-- ## Test Engine
local g=require"glua"
local oo=g.oo
local the=require("inbc").the
local NUM=require("inbc").NUM
local SYM=require("inbc").SYM
local DATA=require("inbc").DATA

local go={}

function go.the() oo(the); return true end

function go.sym(  sym,entropy,mode)
  sym= SYM()
  for _,x in pairs{"a","a","a","a","b","b","c"} do sym:add(x) end
  mode, entropy = sym:mid(), sym:div()
  entropy = (1000*entropy)//1/1000
  oo({mid=mode, div=entropy})
  return mode=="a" and 1.37 <= entropy and entropy <=1.38 end

-- The middle and diversity of a set of numbers is called "median" 
-- and "standard deviation" (and the latter is zero when all the nums 
-- are the same).
function go.num(  num,mid,div)
  num=NUM()
  for i=1,100 do num:add(i) end
  mid,div = num:mid(), num:div()
  print(mid ,div)
  return 50<= mid and mid<= 52 and 30.5 <div and div<32 end 

-- Nums store only a sample of the numbers added to it (and that storage 
-- is done such that the kept numbers span the range of inputs).
function go.bignum(  num)
  num=NUM()
  the.nums = 32
  for i=1,1000 do num:add(i) end
  oo(num:nums())
  return 32==#num._has; end

-- Show we can read csv files.
function go.csv(   n) 
  n=0
  csv("../data/auto93.csv",function(row)
    n=n+1; if n> 10 then return else oo(row) end end); return true end

-- Can I load a csv file into a Data?.
function go.data(   d)
  d = DATA("../data/auto93.csv")
  for _,col in pairs(d.cols.y) do oo(col) end
  return true
end

-- Print some stats on columns.
function go.stats(   data,mid,div)
  data = DATA("../data/auto93.csv")
  div  = function(col) return col:div() end
  mid  = function(col) return col:mid() end
  print("xmid", o( data:stats(2, data.cols.x, mid)))
  print("xdiv", o( data:stats(3, data.cols.x, div)))
  print("ymid", o( data:stats(2, data.cols.y, mid)))
  print("ydiv", o( data:stats(3, data.cols.y, div)))
  return true
end

-- distance functions
function go.around(    data,around)
  data = DATA("../data/auto93.csv")
  around = data:around(data.rows[1] )
  for i=1,380,40 do print(around[i].dist, o(around[i].row.cells)) end
  return true end

--  Start up
the = g.cli(the)  
os.exit(g.run(go, the))
-- That's all folks.

