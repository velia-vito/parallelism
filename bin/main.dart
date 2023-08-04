// Project imports:
import 'package:parallelism/parallelism.dart';

// Over 48 cycles, more the cycles, more the time delta
// 02:18.854134s on 01 threads
// 01:36.916452s on 04 threads
// 05:48.823434s on 08 threads (ram bottleneck)

void main(List<String> args) async {
  var paragraphs =
      '''
ROGUE
“Got your message.”

“Johnny look, I've been around long enough to know that anything is possible in
 your fucked up world . . . but I never imagined this, even from you. You must 
 have made a pretty big impression on V for getting her on board with this, so 
 hats off.”

“I'm just wondering how you feel about that Johnny — havin’ another person give 
their life for you. ‘Specially when you’re probably just back to all-nighters 
and cheap tequila, laughing at how stupid she was?”

“Or has your conscience finally learned its lesson — that is, if you’ve even got
one . . .”

“Good luck out there Johnny. And don’t ever come back to Night City.”

Johnny opens his eyes to the ceiling fan, creaking lazily overhead. Of the many
messages from V’s friends and family that he had ghosted, Rogue’s is the one
that consistently hit home, that consistently haunted him. The same Rogue he had
estranged on his reckless quest.

He holds his hands out in front of him, textured sandy skin like his own, broken
up by silvery grey lines instead of the eponymous “silver hand” that was used to
replace the arm he lost in combat. As he slowly gets up, the unfamiliar weight
of breasts adorning his current body awkward, like a toddler learning to walk.
As he walks across the room, his body feels heavy, leaded, like he’s walking
underwater. He wasn’t sure if that was because of how physically and
existentially tired he felt or because of his mind still adjusting to a body
literally packed with over twenty-five kilograms of chrome.

Just back to all-nighters and cheap tequila, laughing at how stupid she was? 
Johnny snorts as he leans over the sink, “Ok Rogue, laughing huh?” He tilts his 
head to the side, letting irritating neon green hair fall off the side of his 
face, putting two purple eyeballs with black concentric circles into full view. 
“This bitches hair is fucking annoying, but if I cut it, I’ll lose the ‘V’ look 
and she’ll probably magically reappear outta Mikoshi, just to rant about how I 
spoiled the look,” Johnny chuckles bitterly, “I wish I could go back to 
all-nighters and cheap tequila Rogue. Trust me, I really do.”

He glances at the shower before promptly slipping off the unbuttoned long coat 
he wore to bed. That black coat was one of V’s favorite possessions, thick but 
comfortable, it has seen a lot more dirt, grime, and viscera than some water on 
the floor. If she was going to be pissy about a coat on the floor, she could 
shove it.

Now under cold water, the one thing that stood out to him was how V’s body was 
so pristine — no scars, no blemishes — and yet he knew for a fact that V was not 
vain, he literally lived within her head for a year. A merc without scars, made 
you rethink just how good she was.

A thud shudders through the walls as he slams them with his balled-up fists. If 
only he had put down his feet, insisted that V take back her body . . . He was 
sure she would have pulled something outta her ass and found a way to live past 
the six-month expiration date Alt gave her. Just another illusory comforter he 
was pulling around himself. He remembered saying as much to her.

V
“No happy endings huh?”

JOHNNY
“No kid, wrong people, wrong city — this ain’t the ‘City of dreams,’ it’s the 
‘City of dead dreams.’”

The feeling of hot piss down his legs under the cold shower somehow centered him 
on the present. As far as he remembered, V used to pee standing all the time, 
that wasn’t as easy as it seemed. He let out another bitten-off half-dead 
chuckle. He was doing that a lot of late. I was all he could do when faced with 
the depths of memory encased in V’s impassive eyes and impressive body. A body 
that he now inherited.

He skips taking a shit, he’s barely eaten anything for that.

He burns his single slice of toast again, his mind empty and distant. He gazes 
at the slice, graduated from golden brown to light black, a million tiny lakes 
of white bread poking through. That was the story of his life, always just a 
little caught up in himself — a few seconds earlier and his toast would be fine, 
just a few weeks earlier and V would be alive while he left with Alt. Heck, just 
a minute or two earlier and there would have been no Alt, no Mikoshi, no 
Soulkiller, no Adam Smasher . . . there would have been no Johnny Silverhand 
to fuck up V’s life — but there’s no point in what ifs. He knew that they were 
fucked this way or that — you play the Corpo line, or you cook alive in digital 
hell. That's what he signed up for when he chose to rebel or was all of that 
self-inflated hot air?

For now though, he had to eat, if not for himself, for V. She gave him a second 
lease on life, he had a responsibility to make the best use of it. He could 
simply throw away the bread and buy more, or skip breakfast altogether, but he 
didn’t deserve that luxury, definitely not after what he allowed V to do. Not 
after just accepting her body.'''
          .split('\n\n');

  var bp = BufferedProcessPrototypeTest<Map<String, int>, Map<String, int>, String, String>(
    processLoop: (sentence) async {
      var characterDist = <String, int>{};

      // loop over string, store character frequency in characterDist
      for (var char in sentence.runes) {
        var sChar = char.toString();

        if (!characterDist.containsKey(sChar)) {
          characterDist[sChar] = 1;
        } else {
          characterDist[sChar] = characterDist[sChar]! + 1;
        }
      }

      return characterDist;
    },
    inputSplitter: (string) async* {
      for (var sentence in string.split('. ')) {
        yield sentence;
      }
    },
    rebuilder: (characterDistParts) {
      var masterDist = <String, int>{};

      for (var charDist in characterDistParts) {
        print('processing part ${charDist.key}');

        for (var key in charDist.value.keys) {
          if (!masterDist.containsKey(key)) {
            masterDist[key] = 1;
          } else {
            masterDist[key] = masterDist[key]! + 1;
          }
        }
      }

      return masterDist;
    },
  );

  var _ = await bp.start();

  for (var paragraph in paragraphs) {
    await bp.send(paragraph);
  }

  bp.kill();

  var __ = bp.stream.listen((event) {
    print(event);
  });
}
