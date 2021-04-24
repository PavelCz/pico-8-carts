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
    x = 0,
    y = 0,
    dir = DIR.R,
    length = 4,
    speed = 0.8
  }
end

function _update()
  update_worm_dir()

  move_worm()
end

function _draw()
  -- Clear the screen
  rectfill(0,0,128,128,CLR.back)

  -- Draw worm
  rectfill(worm.x,worm.y,worm.x+1, worm.y+1,CLR.head)
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

  worm.x += dx
  worm.y += dy
end

function update_worm_dir()
  for dir=0,3 do
    if btn(dir) then
      worm.dir = dir
    end
  end
end
