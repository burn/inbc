local g=require"glua"
local the=g.options[[   
inbc : incremental naive bayes
(c) 2022 Tim Menzies <timm@ieee.org> BSD-2 license
     
Usage: lua inbcgo.lua [Options]
      
Options:
 -g  --go    start-up example            = nothing
 -f  --file  file with csv data          = ../data/auto93.csv
 -h  --help  show help                   = false
 -k  --k     bayes low frequency factor  = 2
 -m  --m     bayes low frequency factor  = 1
 -s  --seed  random number seed          = 937162211
 -w  --wait  wait before classifying     = 10]]

-- ## Objects
local csv, map, obj, o, oo, push, rnd = g.csv, g.map, g.obj, g.o, g.oo, g.push, g.rnd
local COLS,DATA,NUM  = obj"COLS",obj"DATA",obj"NUM"
local ROW,SYM,NB     = obj"ROW",obj"SYM",obj"NB"

-- -----------------------------------------------------------------
-- ## Sym
-- `SYM`s summarize a stream of symbols.
function SYM:new(n,s) 
  self.n=0          -- items seen
  self.at=n or 0    -- column position
  self.mode, self.most = nil,0
  self.name=s or "" -- column name
  self._has={} end  -- kept data

function SYM:add(s) --> SYM. 
  if s~="?" then 
    self.n = self.n+1
    self._has[s] = 1+(self._has[s] or 0) 
    if self._has[s] > self.most then 
      self.most, self.mode = self._has[s], s end end end

function SYM:mid(col) return self.mode end

-- Diversity measure for symbols = entropy.
function SYM:div()
  local function fun(p) return p*math.log(p,2) end
  local e=0; for _,n in pairs(self._has) do if n>0 then e=e-fun(n/self.n) end end
  return e end 

  -- Return how much `x` might belong to `self`. 
function SYM:like(x,prior)
   return ((self._has[x] or 0)+the.m*prior) / (self.n+the.m) end

-- ---------------------------------------------------------------------------
---- `Row` holds one record
function ROW:new(t) 
  self.cells=t         -- one record
  self.usedy=false end -- true if y-values evaluated.

-- ---------------------------------------------------------------------------
-- ## NUM
-- `NUM` ummarizes a stream of numbers.
function NUM:new(n,s) 
  self.at=   n or 0
  self.name= s or ""
  self.n=    0
  self.mu=   0
  self.m2=   0
  self.sd=   0
  self.lo=   math.huge  -- lowest seen
  self.hi=  -math.huge  -- highest seen
  self.w = ((s or ""):find"-$" and -1 or 1) end 

-- Reservoir sampler. Keep at most `the.nums` numbers 
-- (and if we run out of room, delete something old, at random).,  
function NUM:add(n)
  if n~="?" then 
    self.n  = self.n + 1
    self.lo = math.min(n, self.lo)
    self.hi = math.max(n, self.hi)
    local d = n - self.mu
    self.mu = self.mu + d/self.n
    self.m2 = self.m2 + d*(n - self.mu)
    self.sd = (self.n<2  or self.m2<0) and 0 or (self.m2/(self.n-1))^0.5 end end

-- Return middle
function NUM:mid() return self.mu end

-- Return diversity
function NUM:div() return self.sd end

-- Normalized numbers 0..1. Everything else normalizes to itself.
function NUM:norm(n) 
  return x=="?" and x or (n-self.lo)/(self.hi-self.lo + 1E-32) end

-- Return the likelihood that `x` belongs to `i`. <
function NUM:like(x,...)
  local sd, mu = self.sd, self.mu
  if sd==0 then return x==mu and 1 or 1/math.huge end
  return math.exp(-.5*((x - mu)/sd)^2) / (sd*((2*math.pi)^0.5)) end  

-- ----------------------------------------------------------------------------
-- `Columns` Holds of summaries of columns. 
-- Columns are created once, then may appear in  multiple slots.
function COLS:new(names) 
  self.names=names -- all column names
  self.all={}      -- all the columns (including the skipped ones)
  self.klass=nil   -- the single dependent klass column (if it exists)
  self.x={}        -- independent columns (that are not skipped)
  self.y={}        -- depedent columns (that are not skipped)
  for n,s in pairs(names) do
    local col = push(self.all, -- NUMerics start with Uppercase. 
                    (s:find"^[A-Z]" and NUM or SYM)(n,s))
    if not s:find":$" then -- some columns are skipped
       push(s:find"[!+-]" and self.y or self.x, col) -- some cols are goal cols
       if s:find"!$" then print(44); self.klass=col end end end end

-- ----------------------------------------------------------------------------
local load 
function DATA:new(src) 
  self.cols = nil -- summaries of data
  self.rows = {}  -- kept data
  load(src, self) end

function load(src, data)
  local function fun(row) data = data or DATA(); data:add(row) end
  if type(src)=="string" then csv(src, fun) else map(src or {}, fun) end 
  return data end

-- ## Data
-- Add a `row` to `data`. Calls `add()` to  updatie the `cols` with new values.
function DATA:add(xs,    row)
 if   not self.cols 
 then self.cols = COLS(xs) 
 else row= push(self.rows, xs.cells and xs or ROW(xs)) -- ensure xs is a Row
      for _,todo in pairs{self.cols.x, self.cols.y} do
        for _,col in pairs(todo) do 
          col:add(row.cells[col.at]) end end end end

-- Return a new `Data` that mimics structure of `self`. Add `src` to the clone.
function DATA:clone(  src,    out)
  out = DATA()
  out:add(self.cols.names)
  for _,row in pairs(src or {}) do out:add(row) end
  return out end

-- For `showCols` (default=`data.cols.x`) in `data`, show `fun` (default=`mid`),
-- rounding numbers to `places` (default=2)
function DATA:stats(  places,showCols,fun,    t,v)
  showCols, fun = showCols or self.cols.y, fun or "mid"
  t={}; for _,col in pairs(showCols) do 
          v=getmetatable(col)[fun](col)
          v=type(v)=="number" and rnd(v,places) or v
          t[col.name]=v end; return t end

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

-- -----------------------------------------------------------------------------
function NB:new(src,report)
  self.all=DATA()  -- all rows
  self.one={}      -- all rows, divided by the klass symbol
  self.nklasses=0  -- number of different classes
  self.report = report or  -- what to do with classification results
                function(got,want) print(got,want) end
  load(src, self) end

function NB:add(t)
  self:classify(t)   -- incrementally, must classify before updating (else we are cheating)
  self:update(t) end

function NB:classify(t)
  self.all:add(t)  
  local klass,k,one
  local one = self:exists(klass(t))
  one:add(t)  end
 
function NB:update(t)
   self:klassExists(t)

function NB:klassExists(t)
  t = t.cells and t.cells or t
  k = t[self.all.cols.klass.at] 
  if not self.one[k] then 
    self.nklasses = self.nklasses+1
    self.one[k]   = self.all:clone() end 
  return self.one[k] end

function NB:classify(t)
  if (#self.all.rows) > the.wait then
    self.report(self:klass(t),k) end end

return {the=the, DATA=DATA, ROW=ROW, NUM=NUM, SYM=SYM, COLS=COLS, NB=NB}
