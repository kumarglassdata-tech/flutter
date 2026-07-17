import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/services/db_service.dart';

class PersonalizeFeedScreen extends StatefulWidget {
  const PersonalizeFeedScreen({super.key});

  @override
  State<PersonalizeFeedScreen> createState() => _PersonalizeFeedScreenState();
}

class _PersonalizeFeedScreenState extends State<PersonalizeFeedScreen> {
  final List<String> _categories = [
    'Fashion', 'Mobiles', 'Beauty', 'Electronics', 'Home', 'Grocery', 'Sports'
  ];
  
  final Map<String, IconData> _categoryIcons = {
    'Fashion': Icons.checkroom,
    'Mobiles': Icons.smartphone,
    'Beauty': Icons.face_retouching_natural,
    'Electronics': Icons.laptop_mac,
    'Home': Icons.home,
    'Grocery': Icons.local_grocery_store,
    'Sports': Icons.sports_soccer,
  };

  final Set<String> _selectedCategories = {};
  
  // Ratings from 1 to 5 (Disagree to Agree)
  int _brandRating = 3;
  int _costRating = 3;
  int _speedRating = 3;
  int _reviewsRating = 3;
  int _impulseRating = 3;
  int _routineRating = 3;
  
  bool _isLoading = false;

  Future<void> _startShopping() async {
    setState(() => _isLoading = true);
    
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    
    if (userId != null) {
      final dbService = DbService();
      await dbService.savePreferences(
        userId: userId,
        categories: _selectedCategories.join(','),
        brandRating: _brandRating,
        costRating: _costRating,
        speedRating: _speedRating,
        reviewsRating: _reviewsRating,
        impulseRating: _impulseRating,
        routineRating: _routineRating,
      );
      
      await auth.setHasPreferences(true);
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
      context.go('/home');
    }
  }

  Widget _buildRatingRow(String title, String description, int currentValue, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87, fontSize: 14),
              children: [
                TextSpan(text: title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                TextSpan(text: ' $description'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Text('Disagree', style: TextStyle(fontSize: 12, color: Colors.grey))),
                ...List.generate(5, (index) {
                  return Radio<int>(
                    value: index + 1,
                    groupValue: currentValue,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: Theme.of(context).primaryColor,
                  );
                }),
                const Expanded(child: Text('Agree', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey))),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Personalize Your Feed', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Description
            Container(
              width: double.infinity,
              color: theme.primaryColor,
              padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              child: const Text(
                'Tell us what you love to shop!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What are you looking for? (Select multiple)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Categories List
                    SizedBox(
                      height: 85,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategories.contains(cat);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedCategories.remove(cat);
                                } else {
                                  _selectedCategories.add(cat);
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: isSelected ? theme.primaryColor.withOpacity(0.1) : theme.cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? theme.primaryColor : theme.dividerColor.withOpacity(0.1), 
                                        width: isSelected ? 2 : 1
                                      ),
                                    ),
                                    child: Icon(
                                      _categoryIcons[cat],
                                      color: isSelected ? theme.primaryColor : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(),
                    ),
                    
                    const Text(
                      'Rate your shopping habits:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildRatingRow('1. Brand:', 'I prefer buying from well-known, premium brands.', _brandRating, (val) => setState(() => _brandRating = val!)),
                    _buildRatingRow('2. Cost:', 'Finding the absolute lowest price is my top priority.', _costRating, (val) => setState(() => _costRating = val!)),
                    _buildRatingRow('3. Speed:', 'I strictly prefer items available for immediate local delivery.', _speedRating, (val) => setState(() => _speedRating = val!)),
                    _buildRatingRow('4. Reviews:', 'I strictly rely on high ratings and many reviews before buying.', _reviewsRating, (val) => setState(() => _reviewsRating = val!)),
                    _buildRatingRow('5. Impulse:', 'I make quick, impulsive decisions when I see something I like.', _impulseRating, (val) => setState(() => _impulseRating = val!)),
                    _buildRatingRow('6. Routine:', 'I tend to buy the same types of products repeatedly.', _routineRating, (val) => setState(() => _routineRating = val!)),
                    
                    const SizedBox(height: 8),
                    
                    // Start Shopping Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _startShopping,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Start Shopping', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    // Extra padding at the bottom for scroll comfort
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

