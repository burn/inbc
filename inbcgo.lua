local g=require"glua"

-- ## Test Engine
local g=require"glua"
local o=g.o
local oo=g.oo
local the=require("inbc").the
local NUM=require("inbc").NUM
local SYM=require("inbc").SYM
local NB=require("inbc").NB
local DATA=require("inbc").DATA

local go={}

function go.the() oo(the) end

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

-- Show we can read csv files.
function go.csv(   n) 
  n=0
  g.csv("../data/auto93.csv",function(row)
    n=n+1; if n> 10 then return else oo(row) end end); return true end

-- Can I load a csv file into a Data?.
function go.data(   d)
  d = DATA("../data/auto93.csv")
  for _,col in pairs(d.cols.y) do oo(col) end
  return d.cols.y[1].mu//1 == 2970 and d.cols.y[1].sd//1 == 846 end

function go.clone(   data1,data2)
  data1 = DATA("../data/auto93.csv")
  data2 = data1:clone(data1.rows)
  print("data1", o( data1:stats(2, data1.cols.x)))
  print("data2", o( data2:stats(2, data2.cols.x)))
  return data1.cols.y[1].mu == data2.cols.y[1].mu end

 -- Print some stats on columns.
function go.stats(   data,mid,div)
  data = DATA("../data/auto93.csv")
  print("xmid", o( data:stats(2, data.cols.x)))
  print("xdiv", o( data:stats(3, data.cols.x, "div")))
  print("ymid", o( data:stats(2, data.cols.y)))
  print("ydiv", o( data:stats(3, data.cols.y, "div")))
end

-- Print some stats on columns.
function go.nb()
  local data = NB("../data/diabetes.csv") end
  
--  Start up
the = g.cli(the)  
os.exit(g.run(go, the))
-- That's all folks.

