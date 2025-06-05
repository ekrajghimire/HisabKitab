Future<String> _getPaidByText(String userId, bool isCurrentUser) async {
  if (isCurrentUser) return 'Paid by you';
  final userName = await UserService().getUserDisplayName(userId);
  return 'Paid by ${userName ?? 'Unknown'}';
}
