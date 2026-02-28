class Contact {
  final String serviceName;
  final String phoneNumber;

  Contact({required this.serviceName, required this.phoneNumber});
}

// Пример списка тестовых контактов
final List<Contact> emergencyContacts = [
  Contact(serviceName: 'Полиция', phoneNumber: '102'),
  Contact(serviceName: 'Скорая помощь', phoneNumber: '103'),
  Contact(serviceName: 'Пожарная служба', phoneNumber: '101'),
  Contact(serviceName: 'Газовая служба', phoneNumber: '104'),
];
