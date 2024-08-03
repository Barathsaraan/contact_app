import 'dart:convert';
import 'dart:io';

import 'package:contact/screen/add_contact.dart';
import 'package:contact/screen/editpage_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  final Map<String, List<Map<String, dynamic>>> _groupedContacts = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsList = prefs.getStringList('contacts') ?? [];
    setState(() {
      _contacts = contactsList
          .map((contact) => Map<String, dynamic>.from(json.decode(contact)))
          .toList();
      _contacts.sort(
          (a, b) => a['name'].toLowerCase().compareTo(b['name'].toLowerCase()));
      _filteredContacts = List.from(_contacts);
      _groupContacts();
    });
  }

  void _groupContacts() {
    _groupedContacts.clear();
    for (var contact in _filteredContacts) {
      String firstLetter = contact['name'][0].toUpperCase();
      if (!_groupedContacts.containsKey(firstLetter)) {
        _groupedContacts[firstLetter] = [];
      }
      _groupedContacts[firstLetter]!.add(contact);
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = List.from(_contacts);
      } else {
        _filteredContacts = _contacts
            .where((contact) =>
                contact['name'].toLowerCase().contains(query.toLowerCase()) ||
                contact['phone'].contains(query))
            .toList();
      }
      _groupContacts();
    });
  }

  Future<void> _deleteContact(int index) async {
    setState(() {
      _contacts.removeAt(index);
      _filteredContacts = List.from(_contacts);
      _groupContacts();
    });
    await _saveContacts();
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> contactsList = _contacts.map((c) => json.encode(c)).toList();
    await prefs.setStringList('contacts', contactsList);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    var status = await Permission.phone.request();
    if (status.isGranted) {
      try {
        await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      } catch (e) {
        print('Error launching phone call: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to make phone call: $e')),
        );
      }
    } else if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone call permission denied')),
      );
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  void _showContactDetails(Map<String, dynamic> contact) {
    showModalBottomSheet(
      elevation: 0,
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (contact['imagePath'] != null &&
                      contact['imagePath'].isNotEmpty)
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: FileImage(File(contact['imagePath'])),
                    )
                  else
                    CircleAvatar(
                      radius: 35,
                      child: Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red,
                              width: 4.0,
                            ),
                            color: const Color.fromRGBO(7, 45, 68, 1)),
                        child: const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    contact['name'],
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(contact['email'], style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(contact['phone'], style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _makePhoneCall(contact['phone']),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      iconColor: Colors.red,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        title: const Text('Contact App',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromRGBO(7, 45, 68, 1),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: TextStyle(color: Colors.white),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                ),
                onChanged: _filterContacts,
              ),
            ),
          ),
          Expanded(
            child: _groupedContacts.isEmpty
                ? Center(
                    child: Text(
                      'No data found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _groupedContacts.length,
                    itemBuilder: (context, index) {
                      String letter = _groupedContacts.keys.elementAt(index);
                      List<Map<String, dynamic>> contacts =
                          _groupedContacts[letter]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              letter,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...contacts.map((contact) => Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  leading: contact['imagePath'] != null &&
                                          contact['imagePath'].isNotEmpty
                                      ? CircleAvatar(
                                          radius: 30,
                                          backgroundImage: FileImage(
                                              File(contact['imagePath'])),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.red,
                                                width: 4.0,
                                              ),
                                            ),
                                          ),
                                        )
                                      : CircleAvatar(
                                          radius: 30,
                                          child: Container(
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.red,
                                                  width: 4.0,
                                                ),
                                                color: const Color.fromRGBO(
                                                    7, 45, 68, 1)),
                                            child: const Icon(
                                              Icons.person,
                                              size: 45,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                  title: Text(contact['name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(contact['email']),
                                      Text(contact['phone']),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (String value) {
                                      if (value == 'edit') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditContactScreen(
                                              contact: contact,
                                              index: _contacts.indexOf(contact),
                                            ),
                                          ),
                                        ).then((_) => _loadContacts());
                                      } else if (value == 'delete') {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title:
                                                  const Text('Delete Contact'),
                                              content: const Text(
                                                  'Are you sure you want to delete this contact?'),
                                              actions: <Widget>[
                                                TextButton(
                                                  child: const Text('Cancel'),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                                TextButton(
                                                  child: const Text('Delete'),
                                                  onPressed: () {
                                                    _deleteContact(_contacts
                                                        .indexOf(contact));
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showContactDetails(contact),
                                ),
                              )),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromRGBO(7, 45, 68, 1),
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
        onPressed: () async {
          bool? result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddContactScreen(),
            ),
          );

          // Refresh the contacts if a new contact was added
          if (result == true) {
            _loadContacts();
          }
        },
      ),
    );
  }
}
