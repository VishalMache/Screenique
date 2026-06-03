import 'package:flutter/material.dart';
import 'country_mapper.dart';

class CountrySearchSheet extends StatefulWidget {
  final Function(String iso) onSelect;
  const CountrySearchSheet({super.key, required this.onSelect});

  @override
  State<CountrySearchSheet> createState() => _CountrySearchSheetState();
}

class _CountrySearchSheetState extends State<CountrySearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allCountries = CountryMapper.all.entries.toList();
    final results = _query.isEmpty 
        ? allCountries 
        : allCountries.where((e) => e.value.toLowerCase().contains(_query.toLowerCase())).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4EC),
        border: Border(top: BorderSide(color: Color(0xFF111111), width: 1.5)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              height: 4,
              width: 40,
              color: const Color(0xFF111111),
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              style: const TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "SEARCH COUNTRY...",
                hintStyle: TextStyle(color: const Color(0xFF111111).withOpacity(0.5), fontFamily: 'Impact', letterSpacing: 2),
                filled: true,
                fillColor: const Color(0xFFD9D4C7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
                ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
          ),
          const SizedBox(height: 16),
          
          // Results
          Expanded(
            child: ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF111111), height: 1, thickness: 1.5),
              itemBuilder: (context, index) {
                final iso = results[index].key;
                final name = results[index].value;
                final flag = CountryMapper.getFlagEmoji(iso);
                
                return ListTile(
                  leading: Text(flag, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    name.toUpperCase(),
                    style: const TextStyle(color: Color(0xFF111111), fontFamily: 'Impact', fontSize: 16, letterSpacing: 1),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelect(iso);
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
