import '../../models/player.dart';

String playerSortKey(Player player) {
  final trimmedName = player.name.trim();
  if (trimmedName.isNotEmpty) {
    return trimmedName.toLowerCase();
  }
  return player.role.name.trim().toLowerCase();
}

List<Player> sortedPlayersByDisplayName(Iterable<Player> players) {
  final list = players.toList();
  list.sort((a, b) => playerSortKey(a).compareTo(playerSortKey(b)));
  return list;
}
