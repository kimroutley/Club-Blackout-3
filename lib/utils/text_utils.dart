String toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text.toLowerCase().split(' ').map((word) {
    if (word.isNotEmpty) {
      return word[0].toUpperCase() + word.substring(1);
    }
    return '';
  }).join(' ');
}
