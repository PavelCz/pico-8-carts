pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
-- Pico-8 cartridge for LD48

---- Bugs that might or might not still exist ----
-- diggin sound randomly cuts out?- Seems to be fixed?
-- Top of screen when there is cavity bug
-- Hinder worm from going right in cavity in the one level
-- Edge case at the right edge of the screen in the corner?
-- Not sure if I am a fan of the workaround for the worm gap at high speed bug
--   the workaround causes the non-right corners at high speed

---- Potential future TODOS ----
-- Regular food adds speed? -- Potential idea, I will not do it for now
-- Code cleanup -- of course -- separate lua files?

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
  body = 15,
  cavity = 1
}

SFX = {
  hit = 0,
  collide = 1,
  eat = 2,
  dig = 3,
  new_level = 4,
  speed = 5,
  slow = 6,
  game_over = 7,
  restart = 14,
}

level_text = {
  -- Level 1
  {
    {x = 8, y = 18, text = "food = growth\navoid hitting your body"},
    {x = 16, y = 40, text = "wormy leaves cavities"},
    {x = 6, y = 60, text = "wormy will fall in cavities"}
  },
  -- Level 2
  {
    {x = 6, y = 50, text = "you'll\nneed\nmore\nspeed"},
    {x = 6, y = 112, text = "purple will make you faster"},
  },
  -- Level 3
  {
    {x = 48, y = 6, text = "      watch out!\ndon't hit the magma\n"},
    {x = 27, y = 43, text = "these   will slow you"},
  }
}

-- Determines the level order and where on the pico-8 map they are located
-- exit gives the screen edge of the exit, exit_start and exit_end the exact location at that edge
-- hud_color changes hud_color for a certain map
levels = {
  {start_x = 5, start_y = 0, origin_x = 0, origin_y = 0, exit = DIR.D, exit_start = 0, exit_end = 72, hud_color = 7},
  {start_x = 5, start_y = 0, origin_x = 0, origin_y = 128, exit = DIR.R, exit_start = 0, exit_end = 96, hud_color = 7},
  {start_x = 5, start_y = 0, origin_x = 128, origin_y = 128, exit = DIR.D, exit_start = 0, exit_end = 128, hud_color = 7},
  {start_x = 5, start_y = 0, origin_x = 128 * 2, origin_y = 0, exit = DIR.D, exit_start = 0, exit_end = 128, hud_color = 0},
  {start_x = 5, start_y = 0, origin_x = 128 * 2, origin_y = 128, exit = DIR.D, exit_start = 0, exit_end = 24, hud_color = 0},
  {start_x = 5, start_y = 0, origin_x = 128 * 3, origin_y = 0, exit = DIR.D, exit_start = 90, exit_end = 128, hud_color = 7},
  {start_x = 5, start_y = 0, origin_x = 128 * 3, origin_y = 128, exit = DIR.D, exit_start = 0, exit_end = 128, hud_color = 7},
  
  -- Last level = end game screen, has no exit
  {start_x = 5, start_y = 0, origin_x = 128, origin_y = 0, exit = -1, exit_start = 0, exit_end = 0},
}

-- Channel 1 and 2 for music
dig_channel = 2
sfx_channel = -1 -- Automatically choose available channel

-- Other constants
MAGMA_DAMAGE = 3

-- Other variables
wait = 0

-- SPECIAL GAME CALLBACKS --
function _init()
  worm = {
    x = 5,  -- The exact location. prev_x/y only save integer values
    y = 0,
    dir = DIR.R,
    length = 10,
    speed = 0.5,
    prev_x = {5},
    prev_y = {0},
    invincible = 0,
    airtime = 0
  }

  fx = {
    flash_red = 0,
    max = 0,
    min = 0
  }

  current_level = {
    number = 0, -- 0 is the title screen
    food = {},
    fire = {},
    cavities = {},
    speed = {},
    slowers = {}
  }

  game_over = false

  digging_sound = false

  music_playing = false
  mute = false

  worm_starting_data = {}

  title_screen = true
end

function _update()

  -- This allows to pause the game for some number of frames
  if wait > 0 then
    wait -= 1
    return
  end


  -- Restart level
  if btnp(5) then -- X button
    if current_level.number == 0 then
      next_level() -- Start at Level 1
    elseif game_over or current_level.number == #levels then
      -- Start all the way from the beginning
      _init()
      -- We wait here because when pressing the restart buttin it would often immediately start, because
      -- the start game button is the same
      -- Alternative solution, only start game when z + x is pressed. This would mean muting the music int
      -- the main screen should probably be disabled, which is fine
      -- wait = 15 -- Should not be necessary anymore due to btn_p_
      return
    else
      -- Restart only the the current level
      restart_level()
    end 
  end

  -- Mute sound
  if btnp(4) then -- Z button
    mute = not mute
  end


  if not music_playing and not mute then
    music(1, 200, 3)
    music_playing = true
  elseif music_playing and mute then
    music_playing = false
    music(-1)
  end
  
  -- If we are at the title screen ignore the rest of the update code
  if current_level.number <= 0 then
    return
  end


  -- Misc Updates
  if worm.length < 1 then -- GAME OVER
    sfx(SFX.game_over, sfx_channel)
    game_over = true
    worm.length = 100 -- So this doesn't get triggered again
    worm.x = 0
    worm.y = 0
    worm.speed = 0
    worm.airtime = 0
    sfx(SFX.dig, -2) -- -2 disables sound
    mute = true
    return
  end

  if worm.invincible > 0 then
    worm.invincible -= 1
  end

  -- Update FX
  if fx.flash_red > 0 then
    fx.flash_red -= 1
  end
  if fx.max > 0 then
    fx.max -= 1
  end
  if fx.min > 0 then
    fx.min -= 1
  end

  if not digging_sound and worm.airtime < 1 then
    digging_sound = true -- Toggle flag
    sfx(SFX.dig, dig_channel)
  elseif digging_sound and worm.airtime >= 4 then
    digging_sound = false
    sfx(SFX.dig, -2) -- -2 disables sound
  end

  update_worm_dir()

  update_cavities()

  move_worm()

  handle_self_collision()

  handle_level_collision()

end

function _draw()

  -- Special screens
  -- Title screen
  if current_level.number == 0 then
    rectfill(0,0,128,128,CLR.back)
    print("wormy's", 32, 28, 15)
    print("dangerous", 44, 35, 8)
    print("dig", 70, 42, 15)
    print("press x to start", 32, 64, 7)
    print("z to mute music", 32, 72, 7)
    -- hack addition to title screen
    line(28,27,28,35, 15)
    line(28,35,40,35, 15)
    line(40,35,40,42, 15)
    line(40,42,66,42, 15)
    line(66,42,66,49, 15)
    line(66,49,86,49, 15)
    pset(87,49,14)
    return
  end
  -- Game over screen
  if game_over then 
    cls()
    print("game over", 48, 32, 7)
    print("press x to restart", 32, 48, 7)
    return
  end


  local orig_x = levels[current_level.number].origin_x
  local orig_y = levels[current_level.number].origin_y
  local column_x = orig_x / 8
  local column_y = orig_y / 8


  -- Clear the screen
  rectfill(0,0,128,128,CLR.back)

  -- FLAG 1 --

  map(column_x,column_y,0,0,16,16,0x2)

  -- BETWEEN FLAG 1 and 2

  local text_colour = 15
  -- Draw special level texts
  for text in all(level_text[current_level.number]) do
    print(text.text, text.x, text.y, text_colour)
  end

  -- TEXT FOR END GAME SCREEN
  if current_level.number == #levels then
    print("you reached the end", 24, 30, text_colour)
    print("score: "..(worm.length * 10).."\n\ngood job!", 44, 38, text_colour)
    print("thank you for playing my game", 6, 70, text_colour)
    print("PRESS X TO RESTART", 22, 86, 7)
  end

  -- Draw cavities
  for x=1,128 do
    for y=1,128 do
      if current_level.cavities[x][y] then
        pset(x-1, y-1, CLR.cavity)
      end
    end
  end

  -- FLAG 2 --

  map(column_x,column_y,0,0,16,16,0x4)

  -- FLAG 6 --

  map(column_x,column_y,0,0,16,16,0x40)

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

  -- Special effects
  if fx.flash_red > 0 then
    if (fx.flash_red / 4) % 2 == 1 then
      rectfill(0,0,128,128,8)
    end
  end
  if fx.max > 0 then
    if fx.max > 30 then
      rectfill(0,0,128,128,2)
    end
    if fx.max > 10 then
      print("max speed", 50, 58, 7)
    end
  end
  if fx.min > 0 then
    if fx.min > 30 then
      rectfill(0,0,128,128,7)
    end
    if fx.min > 10 then
      print("min speed", 50, 58, 0)
    end
  end

  -- Draw HUD
  -- Set text color based on level
  local hud_color = levels[current_level.number].hud_color
  if current_level.number != #levels then
    print("l"..current_level.number.."/"..(#levels-1).." lENGTH: "..worm.length, 64, 0, hud_color)
  end
end
-----

function init_level()
  -- Save worm data from beginning of level for potential restart
  worm_starting_data.x = worm.x
  worm_starting_data.y = worm.y
  worm_starting_data.speed = worm.speed
  worm_starting_data.invincible = worm.invincible
  worm_starting_data.prev_x = {worm.x}
  worm_starting_data.prev_y = {worm.y}
  worm_starting_data.airtime = worm.airtime
  worm_starting_data.length = worm.length
  worm_starting_data.dir = worm.dir


  for x=1,128 do
    current_level.food[x] = {}
    current_level.fire[x] = {}
    current_level.cavities[x] = {}
    current_level.speed[x] = {}
    current_level.slowers[x] = {}
    for y=1,128 do
      -- First set boolean vals
      current_level.food[x][y] = false
      current_level.fire[x][y] = false
      current_level.cavities[x][y] = false
      current_level.speed[x][y] = false
      current_level.slowers[x][y] = false
    
      -- Get current origin
      local orig_x = levels[current_level.number].origin_x
      local orig_y = levels[current_level.number].origin_y
      -- TODO: seperate between sprites with a game effect and purely decorative sprites based on flags
      -- Get pixel coordinates
      local pix_x = orig_x + x-1
      local pix_y = orig_y + y-1
      local sprite_num = mget(flr(pix_x / 8), flr(pix_y / 8))

      if not fget(sprite_num, 0) then -- Sprites with this flag set are decorative
      -- Determine cell location on the sprite sheet
        local ss_cell_x = sprite_num % 16
        local ss_cell_y = flr(sprite_num / 16)
        -- Determine sprite sheet location
        local ss_x = ss_cell_x * 8 + pix_x % 8
        local ss_y = ss_cell_y * 8 + pix_y % 8
        local color = sget(ss_x, ss_y)
        -- Determine type of pixel based on color
        if color == 3 or color == 11 then -- Greens
          current_level.food[x][y] = true
        elseif color == 8 or color == 9 or color == 10 then -- red, orange yellow
          current_level.fire[x][y] = true
        elseif color == 1 or color == 5 then
          current_level.cavities[x][y] = true
        elseif color == 2 then -- Purple
          current_level.speed[x][y] = true
        elseif color == 7 then -- White
          current_level.slowers[x][y] = true
        end
      end
    end
  end  
end

function update_cavities()
  local x = worm.prev_x[worm.length]
  local y = worm.prev_y[worm.length]
  if x != nil and y != nil and current_level.cavities[x] != nil then
    current_level.cavities[x+1][y+1] = true
  end
  -- Doing this also for the second to last body part prevents gaps in case the length gets reduced
  local x = worm.prev_x[worm.length-1]
  local y = worm.prev_y[worm.length-1]
  if x != nil and y != nil and current_level.cavities[x] != nil then
    current_level.cavities[x+1][y+1] = true
  end
end

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

  -- UPDATE BODY/TAIL

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

    -- Sometimes we move more than one tile at high speeds
    -- We want to prevent gaps in the worm
    -- In a correct worm no part is more than one tile distance from the previous part
    -- (Less than one if worm has corners)
    -- Clean out any gaps in the updated data
    for i=2,worm.length do
      if worm.prev_x[i] != nil then
        -- FIX X
        local diff_x = worm.prev_x[i-1] - worm.prev_x[i]  -- closer to head - closer to end
        -- Check that body is attached to previous part
        if abs(diff_x) >= 2 then
          -- Move closer to previous part
          -- this should move such that they are only one apart
          -- >_>  => >>
          worm.prev_x[i] += (diff_x - sgn(diff_x))
        end
        -- FIX Y
        local diff_y = worm.prev_y[i-1] - worm.prev_y[i]  -- closer to head - closer to end
        -- Check that body is attached to previous part
        if abs(diff_y) >= 2 then
          -- Move closer to previous part
          worm.prev_y[i] += (diff_y - sgn(diff_y))  -- this should move such that they are only one apart
        end
      end
    end
  end

end

function update_worm_dir()
  if worm.airtime <= 0 then
    for dir=0,3 do
      if btn(dir) then
        if dir != opposite(worm.dir) then -- Prevent worm 180 degree turn
          worm.dir = dir
          break
        end
      end
    end
  end

  collision = handle_screen_collision()
  if (collision) sfx(SFX.collide, sfx_channel)

end

function opposite(dir)
  if (dir == 0) return 1
  if (dir == 1) return 0
  if (dir == 2) return 3
  if (dir == 3) return 2
end 

-- Handle collisions, return true if collision is detected
-- In case of a collision player input should be ignored
function handle_screen_collision()
  -- DETECT COLLISIONS
  -- Collisions are handled by changing the direction clockwise, unless the opposite arrow butt ins pressed
  -- Left and right side collision
  if worm.dir == DIR.L then
    if worm.prev_x[1] - 1 < 0 then -- Check pixel position
      if levels[current_level.number].exit == DIR.L and worm.prev_y[1] >=  levels[current_level.number].exit_start
      and worm.prev_y[1] <=  levels[current_level.number].exit_end then -- This side is the exit
        next_level()
        return false
      end
      if worm.airtime > 1 then
        worm.dir = DIR.D
        return true
      elseif btn(DIR.D) then
        worm.dir = DIR.D
        return false -- Does not count as actual collision (for sound's sake) because player chose direction
      elseif btn(DIR.U) then
        worm.dir = DIR.U
        return false -- As above
      else 
        worm.dir = DIR.U
        return true
      end
    end
  elseif worm.dir == DIR.R then
    if worm.prev_x[1] + 1 > 127 then -- TODO: better alternative?
      if levels[current_level.number].exit == DIR.R and worm.prev_y[1] >=  levels[current_level.number].exit_start
      and worm.prev_y[1] <=  levels[current_level.number].exit_end then -- This side is the exit
        next_level()
        return false
      elseif worm.airtime > 1 then
        worm.dir = DIR.D
        return true
      elseif btn(DIR.U) then
        worm.dir = DIR.U
        return false -- See above
      elseif btn(DIR.D) then
        worm.dir = DIR.D
        return false
      else 
        worm.dir = DIR.D
        return true
      end
    end
  elseif worm.dir == DIR.D then
    if worm.prev_y[1] + 1 > 127 then -- TODO: better alternative?
      if levels[current_level.number].exit == DIR.D and worm.prev_x[1] >=  levels[current_level.number].exit_start
      and worm.prev_x[1] <=  levels[current_level.number].exit_end then -- This side is the exit
        next_level()
        return false
      elseif worm.airtime > 1 then
        worm.dir = DIR.R
        return true
      elseif btn(DIR.R) then
        worm.dir = DIR.R
        return false -- See above
      elseif btn(DIR.L) then
        worm.dir = DIR.L
        return false
      else 
        worm.dir = DIR.L
        return true
      end
    end
  elseif worm.dir == DIR.U then
    if worm.prev_y[1] - 1 < 0 then -- TODO: better alternative?
      if levels[current_level.number].exit == DIR.U and worm.prev_x[1] >=  levels[current_level.number].exit_start
      and worm.prev_x[1] <=  levels[current_level.number].exit_end then -- This side is the exit
        next_level()
        return false
      elseif worm.airtime > 1 then
        worm.dir = DIR.D
        return true
      elseif btn(DIR.R) then
        worm.dir = DIR.R
        return false -- See above
      elseif btn(DIR.L) then
        worm.dir = DIR.L
        return false
      else 
        worm.dir = DIR.R
        return true
      end
    end
  end

  return false
end

function handle_self_collision()
  if (worm.invincible > 0) return
  
  for i=2,worm.length do
    -- prev_x/y[1] is position of head
    if worm.prev_x[i] == worm.prev_x[1] and worm.prev_y[i] == worm.prev_y[1] then
      sfx(SFX.hit, sfx_channel)
      worm.length -= 1 -- TODO: check for death
      worm.invincible = 20 -- Grant short term invincibility, mostly to prevent more than one damage from self collisions
      fx.flash_red = 20 -- Flash screen red
      break
    end
  end
end

function handle_level_collision()
  -- Convert integer worm position into indices
  local x = worm.prev_x[1] + 1
  local y = worm.prev_y[1] + 1

  if current_level.food[x] != nil then
    if current_level.food[x][y] then
      sfx(SFX.eat, sfx_channel)
      worm.length += 1
      current_level.food[x][y] = false -- Food eaten
    elseif current_level.fire[x][y] then
      if worm.invincible <= 0 then
        sfx(SFX.hit, sfx_channel)
        worm.length -= MAGMA_DAMAGE -- Magma damage
        worm.invincible = 20
        fx.flash_red = 20
      end
    elseif current_level.speed[x][y] then
      sfx(SFX.speed, sfx_channel)
      worm.speed += 0.05
      current_level.speed[x][y] = false
      if worm.speed > 1.4 then
        worm.speed = 1.4
        if (fx.max <= 0) fx.max = 35
      end
    elseif current_level.slowers[x][y] then
      sfx(SFX.slow, sfx_channel)
      worm.speed -= 0.05
      current_level.slowers[x][y] = false
      if worm.speed < 0.25 then
        worm.speed = 0.25
        if (fx.min <= 0) fx.min = 35
      end
    elseif current_level.cavities[x][y] then -- There will never be a cavity under fire
      worm.airtime += worm.speed -- With airtime we don't count the number of frames we were in the air, but the number of pixels
      -- The number of pixels the worm will fly horizontally before droppting, based on the speed
      local horizontal_duration = ceil(8 * worm.speed) -- TODO: floor or ceil?
      if flr(worm.airtime) > 0 and flr(worm.airtime) % horizontal_duration == 0 then
        local fall_dist = worm.airtime / horizontal_duration -- The longer we are in the air, the longer we will fall
        worm.y += fall_dist
        worm.prev_y[1] += fall_dist
        -- In the case we are going upwards we grant short invincibility and turn around the worm, such that going up a hole will not cause extreme amounts of damage
        if worm.dir == DIR.U then
          worm.dir = DIR.D
          worm.invincible = 15
        end
        -- TODO: make it so that falling down quickly doesn't cause gaps in the worm by pulling the tail with the
      end
    else -- Not in cavities
      worm.airtime = 0
    end
  end  
end

function next_level()
  if current_level.number > 0 then -- Do this when going into the next level
    local exit_dir = levels[current_level.number].exit
  

    digging_sound = false

    -- Reset worm position
    local save_x = worm.prev_x[1]
    local save_y = worm.prev_y[1]

    if exit_dir == DIR.D then
      worm.y -= 128
      save_y -= 128
    elseif exit_dir == DIR.U then
      worm.y += 128
      save_y += 128
    elseif exit_dir == DIR.R then
      worm.x -= 128
      save_x -= 128
    elseif exit_dir == DIR.L then
      worm.x += 128
      save_x += 128
    end
    -- Also reset the previous list, so they don't cause cavities on the oppisite side of the screen
    worm.prev_x = {save_x}
    worm.prev_y = {save_y}
  else  -- This is for when starting from the beginning
    -- exit_dir = DIR.D
  end

  current_level.number += 1

  sfx(SFX.new_level)

  init_level()
  
end

function restart_level()
  
  sfx(SFX.restart)

  -- Reset worm to starting data
  worm.x = worm_starting_data.x
  worm.y = worm_starting_data.y
  worm.speed = worm_starting_data.speed
  worm.invincible = worm_starting_data.invincible
  worm.prev_x = {worm_starting_data.x}
  worm.prev_y = {worm_starting_data.y}
  worm.airtime = worm_starting_data.airtime
  worm.length = worm_starting_data.length
  worm.dir = worm_starting_data.dir

  init_level()
end

__gfx__
00000000000000b015d5500000000000000555510000000110000001100000000000000000000000077000000000077000000000000000005555000000055555
0000000000000000115550000000000000005d550000001111100111110000000000000000000000077770000007777000000000050000005655000000005555
000000000000000b1555000000000000000005510000011111111111110000000000000000000000066777777777766000030300555000005150000000000051
000000003000b00051500000500000050000055100011111111111111110000000007777777000000007777777777000000b0b0005d000005550000000000051
0000000000000000155000005500005500000515000111151111111511110000000777777777777007777666666777700000b0000000005d5000000000000055
00000000000000b0d150000055550555000055550011111151111111111110000077700777006770077660000006677000003000000000d00000000000000005
0000000000030000d1550000155550d50005555100151111111151111111111000777067770067760660000000000660000b000005d000000000000000000005
00000000000000005515500001155555000551551111115111151111511111110060777777666776000000000000000000000000000000000000000000000005
00000888880000088000000000888800455515551111111111111111111111110000606077777776770000000000000000000000000000000000000000000000
00008888888800888800000008899880154455550151111111111111111111100000000060777776766700000000000000000000000000000000000000000000
000888999988888898800000889aa988551550550111111111111111151111100060000000077776707707000000000000000000000000000000000000000000
00888999998889999980000089aaaa98555550550111115111111111115111100076060600077777007707000700000000000000000000000000000000000000
0888999aa99899aaa980000089aaaa98550500050111511111111111111111110007777770766777000776070700000000000000000000000000000000000055
088999aaaa999aaaa9880000889aa988000000000111111111111111111111110000077777777660000760070700700000000000000000000000000000000055
0889aa9aaaa99aaaa999880008899880000000001111111111111111111111110000000777777700007600007670700000000000000000000000000000005555
8899aaaaaaaaaaaaaaaa998800888800000000001111511111111111111111110000000000000000076000076077607000000000000000000000000000055555
8899aaaaaaaa9aaaaaaa998802000002455550001111151111111111511111111511111100000000000000760007077615111111111111111111111100000000
0898999aaaaaaa9aa9aa998000000000555555001111111111511111111111001111111500000000000007600076006001111111115115111111111000000000
08999a9aaa9aaaaaaa9a980000000200155555500111111111111111511100001111111100000000000076000760000011111111515111155115115500000000
0898999aaa9aaaaaaa9a9800002000005555dd550111111111115111111000005111111150000000000000007600000088188188858558588818188800000000
08899a9aaaa9a9aaaaa998880000000255555155011115111111111111000000515551155500000000000000000000009989989889a8889a8889999a00000000
088999aa9aa9989aaaa99898200002005d5550550011111111111111110000005555555555500000000000000000000009aa999999999a8999a99aa000000000
88999aaaaaaa99aaa9aa9988002000005155555500111111111111111000000055515155155500000000000000000000000aaa999a9999999a9aaa0000000000
8899aaaaaaaaaaaaaaaa998800000000505545550000111110101101100000005555555565550000000000000000000000000aaaaaaaaaaaaaaa000000000000
8899aaaaaa999aaaaaaa998800000070000555555555555545555555000000000000000000000000000000000011110000000000001111000000000000000000
889a9aaaa9aa9aaaaaaa9880007000000055555555dd555d15551115000110000100011000000000000000000011151000000000001511000000000000000000
8899aaaaaaaaaaaaa9a99800700000000505551d5551555515545d55001511101110115100000111111100000011111000000000001111000000000000000000
8899a99aaa9999a9aa99988000000000555555555555555555555555011111101111111100001151111110000051111000000000001111000000000000000000
0888999999988899999998880007007055051d55505055d555550505001115501511155100001111111510000111110000000000000110000000000000000000
08888899998808899999880007000000555555550000551551500000001511001155111100000151515100000015100000001000000110000000000000000000
0088888888000008888898000000000055555514000055555d550000011110000011011000000000000000000011110000011000000100000000000000000000
00000888800000088008880000000700555555550005555155555000000000000000000000000000000000000011110000111100000100000000000000000000
__gff__
0002050505040404030303030203050540404040050404040303030300000000404040020504040404050303404040004040400205050504040404040404000004040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
3614141414141414141414141414143502000000000000000000000000000004020000000000000000000020212121211616170f14141414141414141414143500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000100000000000000000001010402000000000000000000000000000004020013000000000000000020212121211616160700000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000402000001000000000000330000000004020000010000000000000030212121211616161606060607000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000402000000000000000000000000000004020000001300000000230000302121212516161616161616070000000013000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02000000000000000000000000000004020000000000000000000000000000040200000005060606060607000120212129251616161616161607000000000c0400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000402000000002300000023000000000004111111122526262616162700102121210200252626161616161700000000130400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000c000000000000000d0000000402000d00000000000000000000000004212121211200101225270010212121210200000037151616161700000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000402000000000001000000000000000004313121212111213200000030313131310200000000151616161607000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02000000000000000000000000000004020000000000000000000000330000042900303121213200000000000000001f02000000001516161616273c0000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200050607000507000000000000001502000001002300000c000000000000040200000120220000003300000000000402000000001516161617003d0000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
16061616160616160700000000050616020000000001000000000000000d0004021011112132000000000000000000040200000000151616161700000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1626261616161616160606060616161602000000000000000000000000000004023031313200003700001300000000040200000d00151616162700000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02000025161616161626161616161616020000000c0000000033000809000004020000000000000000130113000000040200000000151616160700003300000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02000000252626262700252626262704020000000000000000000018191a1b04020000000000000000001313000000040200000023151616161708090000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02000000000000000000000000000004020000000a0b000000000000002a2b040e00000000230000000000000000000f020c0023232c2d2d2d2e18191a1b000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020000000005060607030303030303342403030303030303030303030303033411111111111112001011111111111111240303032910212121121f292a2b000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02000000001516161714141414141414141414141414141414141414141414352131212121213200302121212121312136141414141414141414140e0000001f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020000000025161616070000000d000000000000000000000000000000000004020030212132000000303131313200040200000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02000000000025161616070000000000000013000000000000000000000000040200003032000507000d0000000000040200000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000015161616070000000000000000000000000000000000000004020000000000151713000000000000040200000005060606060607000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000015161616170000000000000000000000330001000000000004020000000000151700000000000000040200000015162616161617000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000025261616160700000000000000000033000000000000000004020000000000151700000000000000040200000015170115261617000000230400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02000000000000000015161616070000000000001300000000000000000000040200000000001516070000000000000402003300151606170c1516070000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020000000000393a001516161616060607000000000000000000000013000004020000000000151617000000000000040233000516161616061616170000230400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02000000000000000015161616161616160700000000000000130000000000040200010000002c2d2e0c000000002304021a1b1516161616161616170000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020000000037000000151616161616161616060606070000130013001313131002000000330000000000000000000004022a2b2c2d2d2d2d2d2d2d2e0000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000002516161616161616162626262713130000101200000030020000000000000000000000000000040200000000000000003700000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020c0000000000000000252626262616162700130013000000003032000000040200000a0b00000000003c3938383a040200000000000000001300000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020000002300000000000000000000040e01330000000000000000000000010f020000000000000000003b000000000402000000000000000000001300000d0400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020a0b0000000000000d00002300000411111111111112000000000010111111020000000000000000003b000c0d0004020010111200000c000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000431313131313132000000000020212121020507131300000000003d00001012041111212121111111120000000010120400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2403030303030303030303030303033429000000000000000013001021212121061617030303030303030303032022343131313131313131320000000030320400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000c00002663019650146200c70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000e05019000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002f55034550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
901e0006036100d6100561010610066100c6100000000000000000000000000000000000015600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b61000002d55029550285502a5502e5503255038550335000c5000b5000a500095000850007500065000550004500035000250001500005000050000500005000050000500005000050000500005000050000500
0010000033450374502f3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001e00000e75009750107000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001e7001d7000c7000b7001e7501d7500c7500b75014750157500f7500e7500575004750047500475004750000000000000000000000000000000000000000000000000000000000000000000000000000
012000200b0500a0500b0500000007050060500705000000090500805009050000000b050000000b050000000b0500a0500b0500000007050060500705000000090500805009050000000c050000000b05000000
0110002017750000001775000000177501e75017750000001f750000001f750000001f7501e7501f7500000015750000001575000000157501675015750000001775000000177500000017750167501775000000
012000201775016750177500000013750127501375000000157501475015750000001a750167001875000000177501675017750000001375012750137500000015750147501575000000187501b7001775000000
0110002023750227502375000000237500000023750000001f7501e7501f750000001f750000001f7500000021750207502175000000217500000021750000002375022750237500000023750227502375000000
012000200b0500a0500b0500000007050060500705000000090500805009050000000b050000000b050000000b0500a0500b0500000007050060500705000000090500805009050000000c050100500b05000000
012000000b050000000b0500000007050000000705000000090500000009050000000b050000000b0500000017050000001705000000130500000013050000001505000000150500000017050170500000000000
001000002d0201b030110301c0301c0001c0001c0001c0001c0001c0001c0001c0001c0001c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
03 03424344
01 08424344
00 08094344
00 0a0b4344
00 480c4344
02 0d4c4344

