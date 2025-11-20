// nb_noise v0.1 - imminent gloom
// nb boilerplate v0.1 @sonoCircuit

NB_nb_noise {

   *initClass {

      var synthParams, synthGroup, synthVoices;
      var numVoices = 6;

      // synthParams dictionary hold the key, val pairs of your synth params. these are updated with params changes on norns
      synthParams = Dictionary.newFrom([
         \amp, 0.8,
         \sendA, 0,
         \sendB, 0,
         \timbre, 0.2,
         \noise, 0.3,
         \bias, 0.6,
         \loop, 0.0,
         \shape, 0.1,
         \max_attack, 1,
         \max_release, 3
      ]);

      StartUp.add {

         var s = Server.default;

         s.waitForBoot {

            synthGroup = Group.new(s);
            synthVoices = Array.fill(numVoices, { Group.new(synthGroup) }); // each voice will have it's own node

            SynthDef(\nb_noise_poly,{
               arg
                  out = 0,
                  sendABus = 0,
                  sendBBus = 0,
                  gate = 1,
                  sendA = 0,
                  sendB = 0,
                  amp = 0.8,
                  timbre = 0.2,
                  noise = 0.3,
                  bias = 0.6,
                  freq = 100.0,
                  loop = 0.0,
                  shape = 0.1,
                  max_attack = 1,
                  max_release = 3,
                  vel = 1.0;
               var
                  hz, pulsewidth, sine, saw, square, waveform, threshold, max, attack, release, curve, asr, ararar, env, lpg, snd;

               hz = WhiteNoise.ar(noise) * freq + freq;
               hz = hz.clip(0, SampleRate.ir * 0.5);

               pulsewidth = LinSelectX.kr(timbre * 2, [0, 0.5, 1]);

               sine = SinOsc.ar(hz);
               saw = VarSaw.ar(hz, 0, pulsewidth, 0.61);
               square = Pulse.ar(hz, pulsewidth, 0.667);

               waveform = SelectX.ar(timbre * 2, [saw, sine, square]);
               waveform = SelectX.ar(noise * 2, [waveform, waveform * PinkNoise.ar(noise * 3.5, 1), PinkNoise.ar(3.5)]);
               waveform = waveform.clip(-1, 1);

               threshold = -1 * (bias * 2 - 1);
               max = LeakDC.ar((waveform > threshold * waveform) + (waveform <= threshold * threshold));

               attack = LinSelectX.kr(shape * 3, [0.01, 0.01, max_attack, max_attack]);
               release = LinSelectX.kr(shape * 3, [0.01, max_release, max_release, 0.01]);
               curve = LinSelectX.kr(shape * 3, [-2, -0.5, 0, 0]);

               asr = EnvGen.kr(Env.asr(attack, 1, release, curve: curve), gate, doneAction: 2);
               ararar = EnvGen.kr(Env.new([0, 1, 0, 1, 0], [attack, release, attack, release], releaseNode: 3, loopNode: 1, curve: curve), gate, doneAction: 2);
               env = LinSelectX.kr(loop.lag(attack), [asr, ararar]);

               lpg = LPF.ar(max, env.linexp(0, 1, 200, 20000), env * vel * amp);

               snd = Pan2.ar(lpg).tanh * 0.5;

               Out.ar(out, snd);
               Out.ar(sendABus, sendA * snd);
               Out.ar(sendBBus, sendB * snd);
            }).add;

            OSCFunc.new({ |msg, time, addr, recvPort|
               var i = msg[1].asInteger;
               var freq = msg[2].asFloat;
               var vel = msg[3].asFloat;
               synthVoices[i].set(\gate, -1.05); // force release if playing
               Synth.new(\nb_noise_poly,
                  // send arguments and key, value pairs...
                  [
                     \freq, freq,
                     \vel, vel,
                     \sendABus, ~sendA ? Server.default.outputBus,
                     \sendBBus, ~sendB ? Server.default.outputBus,
                  ] ++ synthParams.getPairs, target: synthVoices[i] // concat the key, value paris from the dictionary
               );
            }, "/nb_noise/note_on");

            OSCFunc.new({ |msg, time, addr, recvPort|
               var i = msg[1].asInteger;
               synthVoices[i].set(\gate, 0); // set gate to 0 -> go into release phase
            }, "/nb_noise/note_off");

            OSCFunc.new({ |msg, time, addr, recvPort|
               var key = msg[1].asSymbol;
               var val = msg[2].asFloat;
               synthGroup.set(key, val);  //update params to the whole synth group. will affect all nodes
               synthParams[key] = val; // and store the changed value in the dictionary.
            }, "/nb_noise/set_param");

            OSCFunc.new({ |msg, time, addr, recvPort|
               synthGroup.set(\gate, -1.05); // force release all nodes
            }, "/nb_noise/panic");

            OSCFunc.new({ |msg, time, addr, recvPort|
               synthGroup.free;
            }, "/nb_noise/free");

         }
      }
   }
}
