   -- nb_noise v0.1 - imminent gloom
   -- nb boilerplate v0.1 @sonoCircuit

   local mu = require 'musicutil'
   local md = require 'core/mods'
   local vx = require 'voice'

   local NUM_VOICES = 6 -- should correspond to the numVoices in the sc file.

   local function dont_panic()
      osc.send({ "localhost", 57120 }, "/nb_noise/panic") 
   end

   local function set_param(key, val)
      osc.send({ "localhost", 57120 }, "/nb_noise/set_param", {key, val}) 
   end

   local function round_form(param, quant, form) -- param formatting (optional)
      return(util.round(param, quant)..form)
   end

   local function add_nb_noise_params()
      params:add_group("nb_noise_group", "nb_noise", 13)
      params:hide("nb_noise_group")
   
      params:add_separator("nb_noise_levels", "levels")
      
      params:add_control("nb_noise_amp", "amp", controlspec.new(0, 1, "lin", 0, 0.8), function(param) return round_form(param:get() * 100, 1, "%") end)
      params:set_action("nb_noise_amp", function(val) set_param('amp', val) end) -- key corresponds to the arg of your synthdef
   
      params:add_separator("nb_noise_sound", "sound")
      
      params:add_control("nb_noise_timbre", "timbre", controlspec.new(0, 1, "lin", 0.001, 0.2))
      params:set_action("nb_noise_timbre", function(val) set_param('timbre', val) end)
      
      params:add_control("nb_noise_noise", "noise", controlspec.new(0, 1, "lin", 0.001, 0.3))
      params:set_action("nb_noise_noise", function(val) set_param('noise', val) end)
      
      params:add_control("nb_noise_bias", "bias", controlspec.new(0, 1, "lin", 0.001, 0.6))
      params:set_action("nb_noise_bias", function(val) set_param('bias', val) end)
      
      params:add_separator("nb_noise_env", "envelope")
      
      params:add_control("nb_noise_shape", "shape", controlspec.new(0.001, 1, "exp", 0.001, 0.1))
      params:set_action("nb_noise_shape", function(val) set_param('shape', val) end)
      
      params:add_control("nb_noise_loop", "loop", controlspec.new(0, 1, "lin", 1, 0, "", 1))
      params:set_action("nb_noise_loop", function(val) set_param('loop', val) end)
      
      params:add_control("nb_noise_max_attack", "max attack", controlspec.new(0.001, 10, "exp", 0.001, 1.0, "s"))
      params:set_action("nb_noise_max_attack", function(val) set_param('max_attack', val) end)

      params:add_control("nb_noise_max_release", "max release", controlspec.new(0.001, 10, "exp", 0.001, 3.0, "s"))
      params:set_action("nb_noise_max_release", function(val) set_param('max_release', val) end)
      
      -- if you want to use the fx mod environment, keep these.
      params:add_control("nb_noise_send_a", "send a", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
      params:set_action("nb_noise_send_a", function(val) set_param('sendA', val) end)
      
      params:add_control("nb_noise_send_b", "send b", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
      params:set_action("nb_noise_send_b", function(val) set_param('sendB', val) end)
   end

   function add_nb_noise_player()
      local player = {
         alloc = vx.new(NUM_VOICES, 2),
         slot = {}
      }

      function player:describe()
         return {
            name = "nb_noise",
            supports_bend = false,
            supports_slew = false
         }
      end
      
      function player:active()
         if self.name ~= nil then
            params:show("nb_noise_group")
            if md.is_loaded("fx") == false then
            params:hide("nb_noise_send_a") -- will automatically hide these params if fx mod is not active
            params:hide("nb_noise_send_b")
            end
            _menu.rebuild_params()
         end
      end

      function player:inactive()
         if self.name ~= nil then
            params:hide("nb_noise_group")
            _menu.rebuild_params()
         end
      end

      function player:stop_all()
         dont_panic()
      end

      function player:modulate(val)
         
      end

      function player:set_slew(s)
         
      end

      function player:pitch_bend(note, amount)

      end

      function player:modulate_note(note, key, value)

      end

      function player:note_on(note, vel)
         local freq = mu.note_num_to_freq(note)
         local slot = self.slot[note]
         if slot == nil then
            slot = self.alloc:get()
            slot.count = 1
         end
         local voice = slot.id - 1 -- sc is zero indexed!
         slot.on_release = function()
            osc.send({ "localhost", 57120 }, "/nb_noise/note_off", {voice})
         end
         self.slot[note] = slot
         osc.send({ "localhost", 57120 }, "/nb_noise/note_on", {voice, freq, vel})
      end

      function player:note_off(note)
         local slot = self.slot[note]
         if slot ~= nil then
            self.alloc:release(slot)
         end
         self.slot[note] = nil
      end

      function player:add_params()
         add_nb_noise_params()
      end

      if note_players == nil then
         note_players = {}
      end

      note_players["nb_noise"] = player
   end

   local function pre_init()
      add_nb_noise_player()
   end

   md.hook.register("script_pre_init", "nb_noise pre init", pre_init)
