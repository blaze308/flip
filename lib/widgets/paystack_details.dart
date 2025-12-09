import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Paystack Details Widget
class PaystackDetails extends StatelessWidget {
  final UserModel user;

  const PaystackDetails({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paystack Payment',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF4ECDC4).withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Payment Status', 'Active'),
              const SizedBox(height: 12),
              _buildDetailRow('Account Email', user.email ?? 'Not set'),
              const SizedBox(height: 12),
              _buildDetailRow('Supported Currencies', 'GHS, NGN, ZAR, KES'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSupportedCountries(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pay with local payment methods in your country.',
                  style: TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportedCountries() {
    final countries = [
      {'name': 'Ghana', 'code': 'GHS', 'flag': '🇬🇭'},
      {'name': 'Nigeria', 'code': 'NGN', 'flag': '🇳🇬'},
      {'name': 'South Africa', 'code': 'ZAR', 'flag': '🇿🇦'},
      {'name': 'Kenya', 'code': 'KES', 'flag': '🇰🇪'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4ECDC4).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Supported Countries',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: countries.map((country) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF4ECDC4).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      country['flag'] as String,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      country['code'] as String,
                      style: const TextStyle(
                        color: Color(0xFF4ECDC4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      country['name'] as String,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
