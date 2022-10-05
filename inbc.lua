local g=require"glua"
local the=g.options[[   
inbc : incremental naive bayes
(c) 2022 Tim Menzies <timm@ieee.org> BSD-2 license
     
USAGE: lua inbcgo.lua [OPTIONS]
      
OPTIONS:
 -e  --eg        start-up example                 = nothing
 -f  --file      file with csv data               = ../data/auto93.csv
 -h  --help      show help                        = false
 -k  --k         bayes low frequency factor       = 2
 -m  --m         bayes low frequency factor       = 1
 -s  --seed      random number seed               = 937162211]]

-- ## Objects
local obj=g.obj
local COLS,DATA,NUM,ROW,SYM=obj"COLS",obj"DATA",obj"NUM",obj"ROWs",obj"SYM"

-- `SYM`s summarize a stream of symbols.
function SYM:new(c,s) 
  return {n=0,          -- items seen
          at=c or 0,    -- column position
          name=s or "", -- column name
          _has={}       -- kept data
         } end

-- `NUM` ummarizes a stream of numbers.
function NUM:new(c,s) 
  return {n=0,at=c or 0, name=s or "", _has={}, -- as per Sym
          lo= math.huge,   -- lowest seen
          hi= -math.huge,  -- highest seen
          isSorted=true,   -- no updates since last sort of data
          w = ((s or ""):find"-$" and -1 or 1)  
         } end

-- `Columns` Holds of summaries of columns. 
-- Columns are created once, then may appear in  multiple slots.
function COLS:new(names) 
  self.names=names -- all column names
  self.all={}      -- all the columns (including the skipped ones)
  self.klass=nil   -- the single dependent klass column (if it exists)
  self.x={}        -- independent columns (that are not skipped)
  self.y={}        -- depedent columns (that are not skipped)
  for c,s in pairs(names) do
    local col = push(self.all, -- NUMerics start with Uppercase. 
                    (s:find"^[A-Z]*" and NUM or SYM)(c,s))
    if not s:find":$" then -- some columns are skipped
       push(s:find"[!+-]" and self.y or self.x, col) -- some cols are goal cols
       if s:find"!$" then self.klass=col end end end end

-- `Row` holds one record
function ROW:new(t) return {
                        cells=t,          -- one record
                        cooked=copy(t), -- used if we discretize data
                        isEvaled=false    -- true if y-values evaluated.
                       } end

function DATA:new(src) 
  self.cols = nil -- summaries of data
  self.rows = {}  -- kept data
  if   type(src) == "string" 
  then csv(src, function(row) self:add(row) end) 
  else for _,row in pairs(src or {}) do self:add(row) end end end

-- ## Sym
function SYM:add(v) --> SYM. 
  if v~="?" then self.n=self.n+1; self._has[v]= 1+(self._has[v] or 0) end end

function SYM:mid(col,    most,mode) 
  most=-1; for k,v in pairs(self._has) do if v>most then mode,most=k,v end end
  return mode end 

-- distance between two values.
function SYM:dist(v1,v2)
  return  v1=="?" and v2=="?" and 1 or v1==v2 and 0 or 1 end

-- Diversity measure for symbols = entropy.
function SYM:div(    e,fun)
  function fun(p) return p*math.log(p,2) end
  e=0; for _,n in pairs(self._has) do if n>0 then e=e - fun(n/self.n) end end
  return e end 

  -- Return how much `x` might belong to `self`. 
function SYM:like(x,prior)
   return ((self._has[x] or 0)+the.m*prior) / (self.n+the.m) end

-- ## NUM
-- Return kept numbers, sorted. 
function NUM:nums()
  if not self.isSorted then table.sort(self._has); self.isSorted=true end
  return self._has end

-- Reservoir sampler. Keep at most `the.nums` numbers 
-- (and if we run out of room, delete something old, at random).,  
function NUM:add(v,    pos)
  if v~="?" then 
    self.n  = self.n + 1
    self.lo = math.min(v, self.lo)
    self.hi = math.max(v, self.hi)
    if     #self._has < the.nums           then pos=1 + (#self._has) 
    elseif math.random() < the.nums/self.n then pos=math.random(#self._has) end
    if pos then self.isSorted = false 
                self._has[pos] = tonumber(v) end end end 

-- distance between two values.
function NUM:dist(v1,v2)
  if   v1=="?" and v2=="?" then return 1 end
  v1,v2 = self:norm(v1), self:norm(v2)
  if v1=="?" then v1 = v2<.5 and 1 or 0 end 
  if v2=="?" then v2 = v1<.5 and 1 or 0 end
  return math.abs(v1-v2) end 

-- Return middle
function NUM:mid() return per(self:nums(), .5) end

-- Return diversity
function NUM:div() return (per(self:nums(), .9) - per(self:nums(),.1))/2.58 end

-- Normalized numbers 0..1. Everything else normalizes to itself.
function NUM:norm(n) 
  return x=="?" and x or (n-self.lo)/(self.hi-self.lo + 1E-32) end

-- Return the likelihood that `x` belongs to `i`. <
function NUM:like(x,...)
  local sd,mu=self:div(), self:mid()
  if sd==0 then return x==mu and 1 or 1/big end
  return math.exp(-.5*((x - mu)/sd)^2) / (sd*((2*math.pi)^0.5)) end  

-- ## Data
-- Add a `row` to `data`. Calls `add()` to  updatie the `cols` with new values.
function DATA:add(xs,    row)
 if   not self.cols 
 then self.cols = COLS(xs) 
 else row= push(self.rows, xs.cells and xs or Row(xs)) -- ensure xs is a Row
      for _,todo in pairs{self.cols.x, self.cols.y} do
        for _,col in pairs(todo) do 
          col:add(row.cells[col.at]) end end end end

-- Return a new `Data` that mimics structure of `self`. Add `src` to the clone.
function DATA:clone(  src,    out)
  out = DATA()
  out:add(self.cols.name)
  for _,row in pairs(src or {}) do out:add(row) end
  return out end

-- For `showCols` (default=`data.cols.x`) in `data`, show `fun` (default=`mid`),
-- rounding numbers to `places` (default=2)
function DATA:stats(  places,showCols,fun,    t,v)
  showCols, fun = showCols or self.cols.y, fun or "mid"
  t={}; for _,col in pairs(showCols) do 
          v=fun(col)
          v=type(v)=="number" and rnd(v,places) or v
          t[col.name]=v end; return t end

-- Distance between rows (returns 0..1). For unknown values, assume max distance.
function DATA:dist(row1,row2)
  local d = 0
  for _,col in pairs(self.cols.x) do 
    d = d + col:dist(row1.cells[col.at], row2.cells[col.at])^the.p end
  return (d/#self.cols.x)^(1/the.p) end

-- Sort `rows` (default=`data.rows`) by distance to `row1`.
function DATA:around(row1,  rows,     fun)
  function fun(row2) return {row=row2, dist=self:dist(row1,row2)} end
  return sort(map(rows or self.rows, fun),lt"dist") end

-- Return `P(H)\*P(E1|H))\*p(E2|H)...`. Work in logs (to cope with small nums)
function DATA:like(row, nklasses, nrows)
  local prior,like,inc,x
  prior = (#self.rows + the.k) / (nrows + the.k * nklasses)
  like  = math.log(prior)
  row = row.cells and row.cells or row
  for _,col in pairs(self.cols.x) do
    x = row[col.at]
    if x ~= nil and x ~= "?" then
      inc  = col:like(x,prior)
      like = like + math.log(inc) end end
  return like end

return {the=the, DATA=DATA, ROW=ROW, NUM=NUM, SYM=SYM, COLS=COLS}
