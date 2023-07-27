import 'package:parallelism/parallelism.dart';

void main(List<String> args) async {
  var p = Process(
    processLoop: (String inp) async {
      return inp.split(' ').length;
    },
  );

  var stream = await p.start();

  for (var str in [
    'There are windows through time that divide the wider galaxy irrevocably into before and after — The dawn of the Jedi, the invasion of Koros Major, Order 66, The destruction of Alderaan, The battle of Jakku, The Amaxine Warrior Crisis, The Second Jedi Restoration — We are on the verge of one such window again.',
    'The legendary Ahsoka Tano is old now — a lover, a teacher, a soldier, a spy, a woman who casts a long shadow . . .',
    'Dead man walking Quinlan Vos is still young.',
    ' Young in body but old in spirit, he would rather be dead . . .',
    'Mandalorian Jedi Grandmaster Grogu and his Jedi order will soon be tested just as they have been in the past . . .',
    'Introverted and star-crossed Lizzy Andor is soon going to be dragged into a messy, precariously balanced galaxy counting down to explosion . . .',
    'The Jedi Eternal Cultists, Time travel, Mandalorian–Nabooean political maneuvering, Crime Syndicate Conglomerations, Spys, Rebels, Humble foot soldiers, all of this on Ord Mantell.',
    ' Will everyone come out whole on the other side?'
  ]) {
    p.send(str);
  }

  p.kill();

  p.stream.listen((event) {
    print(event);
  });

  print('technically killed');
}
