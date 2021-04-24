pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
-- Pico-8 cartridge for LD48

-- Constants
DIR = {  -- Directions correspond to the numbers for the arrow buttons
  L = 0,
  R = 1,
  U = 2,
  D = 3
}

CLR = {
  back = 4,
  head = 14,
  body = 15
}

-- SPECIAL GAME CALLBACKS --
function _init()
  worm = {
    x = 0,  -- The exact location. prev_x/y only save integer values
    y = 0,
    dir = DIR.R,
    length = 10,
    speed = 0.65,
    prev_x = {0},
    prev_y = {0}
  }
end

function _update()

  --collision = handle_screen_collision()
  --if not collision then
  update_worm_dir()
  --end

  move_worm()
end

function _draw()
  -- Clear the screen
  rectfill(0,0,128,128,CLR.back)

  -- Draw worm head
  local int_x = flr(worm.x) -- We floor our 
  local int_y = flr(worm.y)
  rectfill(int_x,int_y,int_x, int_y,CLR.head)
  -- Draw worm body, index 1 is head
  for i=2,worm.length do
    local x = worm.prev_x[i]
    local y = worm.prev_y[i]
    if x != nil and y != nil then
      rectfill(x,y,x, y,CLR.body)
    end
  end
end
-----

function move_worm()
  local dx = 0
  local dy = 0
  if worm.dir == DIR.R then
    dx = 1
  elseif worm.dir == DIR.U then
    dy = -1
  elseif worm.dir == DIR.L then
    dx = -1
  elseif worm.dir == DIR.D then
    dy = 1
  end
  -- Adjust according to speed
  dx *= worm.speed
  dy *= worm.speed

  -- Update worm head position
  worm.x += dx
  worm.y += dy

  -- prev_x/y should only save previous tiles, i.e. integer positions
  -- Therefore, we only update if we have an integer value change in x and y position
  -- If we were to use exact locations for prev_x/y the worm would get shorter if it moves slower, as subsequent positions would be at e.g. 0.5,1,1.5
  -- which would cause segments of the worm to overlap
  local int_x = flr(worm.x)
  local int_y = flr(worm.y)

  if int_x != worm.prev_x[1] or int_y != worm.prev_y[1] then -- Check that the previous floored head position is not equal to the new one, i.e. we moved completely into a new tile
    -- Update previous head positions
    -- Because the last element will be overwritten we start at the second to last element
    for i=worm.length-1,1,-1 do -- Go through elements from the back
      -- Make sure the index exists
      if worm.prev_x[i] != nil then
        -- Shift all elements back
        worm.prev_x[i+1] = worm.prev_x[i]
        worm.prev_y[i+1] = worm.prev_y[i]
      end
    end
    -- Set the head position to the first of the list
    worm.prev_x[1] = int_x
    worm.prev_y[1] = int_y
  end

end

-- Handle collisions, return true if collision is detected
-- In case of a collision player input should be ignored
function handle_screen_collision()
  -- DETECT COLLISIONS
  -- Collisions are handled by changing the direction clockwise
  -- Left and right side collision
  if worm.dir == DIR.L then
    if worm.prev_x[1] - 1 < 0 then -- Check exact position
      -- worm.x = 0
      worm.dir = DIR.U
      return true
    end
  elseif worm.dir == DIR.R then
    if worm.prev_x[1] + 1 > 127 then -- TODO: better alternative?
      -- worm.x = 127
      worm.dir = DIR.D
      return true
    end
  end

  return false
end

function update_worm_dir()

  for dir=0,3 do
    if btn(dir) then
      worm.dir = dir
    end
  end

  handle_screen_collision()
end
