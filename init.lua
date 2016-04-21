uart.setup(0,115200,8,0,1)
print(node.bootreason())
node.setcpufreq(node.CPU160MHZ)

ON         = 16
LED_PIN    = 3
PIXELS     = 5*5*5
TIME_ALARM = 100      --ms
TIME_SLOW  = 100000   --us

RED   = string.char(ON,  0,  0)
GREEN = string.char( 0, ON,  0)
BLUE  = string.char( 0,  0, ON)
WHITE = string.char(ON, ON, ON)
BLACK = string.char( 0,  0,  0)

function colourWheel(index)
  if index < 85 then
    return string.char(index * 3, (255 - index * 3), 0)
  elseif index < 170 then
    index = index - 85
    return string.char((255 - index * 3), 0, index * 3)
  else
    index = index - 170
    return string.char(0, index * 3, (255 - index * 3))
  end
end

rainbow_speed = 1
t = {}
function rainbow(index)
  for pixel = 1, PIXELS do
    t[pixel] = colourWheel((index + pixel * rainbow_speed) % 256)
  end
end

if true then
  ws2812.write(LED_PIN, RED:rep(PIXELS))
  tmr.delay(TIME_SLOW)
  ws2812.write(LED_PIN, GREEN:rep(PIXELS))
  tmr.delay(TIME_SLOW)
  ws2812.write(LED_PIN, BLUE:rep(PIXELS))
  tmr.delay(TIME_SLOW)
  ws2812.write(LED_PIN, WHITE:rep(PIXELS))
  tmr.delay(TIME_SLOW)
  ws2812.write(LED_PIN, BLACK:rep(PIXELS))
end

rainbow_index = 0

function rainbowHandler()
    rainbow(rainbow_index)
    ws2812.write(LED_PIN, table.concat(t))
    rainbow_index = (rainbow_index + 4) % 256
end

wifi.setmode(wifi.STATION)
wifi.sta.config("DuckWifi", "SunnyYellow")

function fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

idx = 0
fname = "cube.html"
fsize = 0;

flist = file.list();
for k,v in pairs(flist) do
    if k == fname then 
        fsize = v
    end
end

function sendFile(c)
    file.open(fname, "r")
    local se = file.seek("set", idx)
    local str = file.read(500)
    if (se == nil or str == nil) then
        idx = 0
        file.close()
        c:close()
        return
    end
    c:send(str)
    idx = idx + 500
    file.close()
    end

if srv then
    srv:close()
end

function stringStarts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function cubeConvert(s, format)
    local l = {}
    for i=1, PIXELS do
      l[i] = "\0\0\0"
    end
    local _x, _y, _z = -2, -2, -2
    local sub = "..."
    if (format == "ascii") then
        sub = "......"
    end
    s:gsub(sub, function(c)

        _x = _x + 2
        _y = _y + 2
        _z = _z + 2
        local n = 0
        n = n + 25 * _z
        n = n + 5 * _y
        if (_y % 2 ~= 0) then
            n = n + 4 - _x
        else 
            n = n + _x
        end
--        print(_x, _y, _z, n+1, c)
        if (format == "ascii") then
            l[n + 1] = fromhex(c)
        else
            l[n + 1] = c
        end
        
        _x = _x - 2
        _y = _y - 2
        _z = _z - 2

        _x = _x + 1

        if (_x > 2) then
          _x = -2
          _y = _y + 1
        end
        if (_y > 2) then
          _y = -2
          _z = _z + 1
        end
        if (_z > 2) then
            return table.concat(l)
        end
    end)
--    for key,value in pairs(l) do print(key,value) end
    return table.concat(l)
end

srv=net.createServer(net.TCP)
srv:listen(80, function(conn)
    conn:on("receive", function(conn,payload)
        local _, _, method, path, vars = string.find(payload, "([A-Z]+) ([^\?]+)\??(.*) HTTP");
        ip, port = conn:getpeer()
        print(ip..":"..port, method, path, vars)
        if path == "/favicon.ico" then
            conn:close();
        end
        if stringStarts(path, "/api/") then
            path = path:sub(6, -1)
            conn:on("sent", function(conn)
                conn:close();
            end) 
            response = "{\"result\":\"error\"}"
            if path == 'start' then
                tmr.alarm(1, TIME_ALARM, tmr.ALARM_AUTO, rainbowHandler)
                response = "{\"result\":\"ok\"}"
            elseif path == 'stop' then
                tmr.stop(1)
                response = "{\"result\":\"ok\"}"
            elseif path == 'off' then
                tmr.stop(1)
                ws2812.write(LED_PIN, BLACK:rep(PIXELS))
                response = "{\"result\":\"ok\"}"
            elseif path == 'on' then
                tmr.stop(1)
                local colors = {WHITE=WHITE, BLACK=BLACK, RED=RED, GREEN=GREEN, BLUE=BLUE};
                if colors[vars] then
                    ws2812.write(LED_PIN, colors[vars]:rep(PIXELS))
                else
                    ws2812.write(LED_PIN, WHITE:rep(PIXELS))
                end
                response = "{\"result\":\"ok\"}"
            elseif path == "frame" then
                tmr.stop(1)
                if vars then
                    ws2812.write(LED_PIN, cubeConvert(vars, "ascii"))
                end
                response = "{\"result\":\"ok\"}"
            end
            conn:send("HTTP/1.1 200 OK\nContent-Length: "..response:len().."\nContent-Type: application/json\n\n"..response)
        else
            conn:send("HTTP/1.1 200 OK\nContent-Length: "..fsize.."\nContent-Type: text/html\n\n")
            conn:on("sent", function(conn)
                sendFile(conn)
            end)  
        end
    end)
end)
