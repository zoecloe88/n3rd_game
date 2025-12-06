#!/usr/bin/env python3
"""
Script to consolidate all trivia template batch files into a single Dart file.
Run this script to generate lib/data/trivia_templates_consolidated.dart
"""

import re
import glob
import os

def extract_templates_from_file(filepath):
    """Extract all TriviaTemplate objects from a batch file."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    templates = []
    
    # Find all TriviaTemplate blocks
    pattern = r'TriviaTemplate\s*\(\s*categoryPattern:\s*"([^"]+)",\s*correctPool:\s*\[(.*?)\],\s*distractorPool:\s*\[(.*?)\],\s*theme:\s*"([^"]+)"'
    
    for match in re.finditer(pattern, content, re.DOTALL):
        category_pattern = match.group(1)
        correct_pool_str = match.group(2)
        distractor_pool_str = match.group(3)
        theme = match.group(4)
        
        # Parse arrays
        correct_pool = [item.strip().strip('"') for item in re.findall(r'"([^"]+)"', correct_pool_str)]
        distractor_pool = [item.strip().strip('"') for item in re.findall(r'"([^"]+)"', distractor_pool_str)]
        
        templates.append({
            'categoryPattern': category_pattern,
            'correctPool': correct_pool,
            'distractorPool': distractor_pool,
            'theme': theme
        })
    
    return templates

def generate_dart_file(templates_by_theme, output_path):
    """Generate the consolidated Dart file."""
    
    dart_content = """import '../services/trivia_generator_service.dart';

/// Consolidated trivia templates from all batch files
/// This file is auto-generated - do not edit manually
class EditionTriviaTemplates {
  static final Map<String, List<TriviaTemplate>> _templatesByTheme = {};
  static final Map<String, List<String>> _editionThemeMapping = {};

  static void initialize() {
    _loadAllTemplates();
    _mapEditionsToThemes();
  }

  static void _loadAllTemplates() {
"""
    
    # Add templates by theme
    for theme, templates in sorted(templates_by_theme.items()):
        dart_content += f'\n    // {theme.upper()} ({len(templates)} templates)\n'
        dart_content += f'    _addTemplates("{theme}", [\n'
        
        for template in templates:
            # Format correct pool
            correct_pool_str = ',\n        '.join([f'"{item}"' for item in template['correctPool']])
            if len(correct_pool_str) > 100:
                correct_pool_str = ',\n        '.join([f'"{item}"' for item in template['correctPool']])
            
            # Format distractor pool
            distractor_pool_str = ',\n        '.join([f'"{item}"' for item in template['distractorPool']])
            
            dart_content += f'''      TriviaTemplate(
        categoryPattern: "{template['categoryPattern']}",
        correctPool: [
          {correct_pool_str}
        ],
        distractorPool: [
          {distractor_pool_str}
        ],
        theme: "{template['theme']}",
      ),
'''
        
        dart_content += '    ]);\n'
    
    dart_content += """  }

  static void _addTemplates(String theme, List<TriviaTemplate> templates) {
    _templatesByTheme.putIfAbsent(theme, () => []).addAll(templates);
  }

  static void _mapEditionsToThemes() {
    // Map edition IDs to their corresponding themes
    _editionThemeMapping = {
      // Geography editions
      'geography': ['geography'],
      'usa_geography': ['geography'],
      'world_capitals': ['geography'],
      'mountains_rivers': ['geography'],
      'islands': ['geography'],
      'national_parks': ['geography'],
      'cities': ['geography'],
      'oceans': ['geography'],
      
      // History editions
      'history': ['history'],
      
      // Science editions
      'biology': ['science'],
      'chemistry': ['science'],
      'physics': ['science'],
      'geology': ['science'],
      'environmental_science': ['science'],
      'marine_biology': ['science'],
      'microbiology': ['science'],
      'genetics': ['science'],
      'neuroscience': ['science'],
      'astronomy': ['astronomy'],
      'meteorology': ['weather'],
      'oceanography': ['science'],
      'botany': ['science'],
      'zoology': ['science'],
      'paleontology': ['science'],
      
      // Medical editions
      'nursing': ['medicine'],
      'medicine': ['medicine'],
      'anatomy': ['medicine'],
      'surgery': ['medicine'],
      'emergency_medicine': ['medicine'],
      'mental_health': ['medicine'],
      'veterinary': ['medicine'],
      'public_health': ['medicine'],
      'pharmacy': ['medicine'],
      'dentistry': ['medicine'],
      
      // Cultural editions
      'black': ['black_culture'],
      'latino': ['latino_culture'],
      'spanish': ['latino_culture'],
      'asian': ['asian_american_culture'],
      'indigenous': ['indigenous_culture'],
      'caribbean': ['caribbean_culture'],
      'middle_eastern': ['middle_eastern_culture'],
      'african': ['african_culture'],
      
      // Professional editions
      'business': ['business'],
      'finance': ['business', 'economics'],
      'law': ['business'],
      'engineering': ['business'],
      'computer_science': ['technology'],
      'marketing': ['business'],
      'real_estate': ['business'],
      'agriculture': ['agriculture'],
      'aviation': ['aviation'],
      'military': ['military'],
      
      // Arts & Entertainment
      'music': ['arts'],
      'movies': ['arts'],
      'tv': ['arts'],
      'art': ['arts'],
      'literature': ['literature'],
      'theater': ['arts'],
      'dance': ['arts'],
      'photography': ['arts'],
      'fashion': ['arts'],
      'architecture': ['arts'],
      'video_games': ['arts'],
      'anime_manga': ['arts'],
      'comics': ['arts'],
      'classical_music': ['arts'],
      'hip_hop': ['arts'],
      
      // Sports
      'sports_general': ['sports'],
      'football': ['sports'],
      'basketball': ['sports'],
      'baseball': ['sports'],
      'soccer': ['sports'],
      'olympics': ['sports'],
      'fitness': ['sports'],
      'extreme_sports': ['sports'],
      
      // Food & Lifestyle
      'food': ['food'],
      'wine': ['food'],
      'beer': ['food'],
      'coffee': ['food'],
      'cooking': ['food'],
      'baking': ['food'],
      
      // Specialty
      'religion': ['religion'],
      'mythology': ['religion'],
      'philosophy': ['philosophy'],
      'technology': ['technology'],
      'nature_wildlife': ['science'],
      'space_exploration': ['astronomy'],
      
      // Kids editions
      'little_n3rd': ['kids_animals', 'kids_colors', 'kids_shapes', 'kids_time', 'kids_food', 'kids_body', 'kids_weather', 'kids_sky', 'kids_house', 'kids_numbers'],
      'junior_n3rd': ['kids_space', 'kids_dinosaurs', 'kids_plants', 'kids_geography', 'kids_science', 'kids_weather_advanced', 'kids_math', 'kids_earth_science', 'kids_geology', 'kids_machines'],
      'elementary_n3rd': ['kids_civics', 'kids_us_government', 'kids_geology_advanced', 'kids_ecosystems', 'kids_water_cycle', 'kids_energy', 'kids_biology', 'kids_ancient_history', 'kids_grammar', 'kids_moon_phases'],
      'middle_school_n3rd': ['middle_school_chemistry', 'middle_school_physics', 'middle_school_literature', 'middle_school_geometry', 'middle_school_ecology', 'middle_school_civics', 'middle_school_cell_division', 'middle_school_plate_tectonics', 'middle_school_art_history', 'middle_school_economics'],
      'high_school_n3rd': ['high_school_literature', 'high_school_american_literature', 'high_school_physics', 'high_school_chemistry', 'high_school_history', 'high_school_calculus', 'high_school_biology', 'high_school_economics', 'high_school_rhetoric', 'high_school_government'],
      'college_prep_n3rd': ['test_prep_vocabulary', 'test_prep_logic', 'test_prep_algebra', 'test_prep_literature', 'test_prep_chemistry', 'test_prep_scientific_method', 'test_prep_geometry', 'test_prep_writing', 'test_prep_statistics', 'test_prep_world_history'],
    };
  }

  /// Get trivia templates for a specific edition
  static List<TriviaTemplate> getTemplatesForEdition(String editionId) {
    final themes = _editionThemeMapping[editionId] ?? [];
    final templates = <TriviaTemplate>[];
    for (final theme in themes) {
      templates.addAll(_templatesByTheme[theme] ?? []);
    }
    return templates;
  }

  /// Get all available themes
  static List<String> getAvailableThemes() {
    return _templatesByTheme.keys.toList();
  }
}
"""
    
    with open(output_path, 'w') as f:
        f.write(dart_content)
    
    print(f"Generated {output_path} with {sum(len(t) for t in templates_by_theme.values())} templates across {len(templates_by_theme)} themes")

if __name__ == '__main__':
    # Find all batch files (now in data/batch_files folder)
    files = sorted(glob.glob('lib/data/batch_files/Untitled-*.swift') + 
                   glob.glob('lib/data/batch_files/Untitled-*.js') + 
                   glob.glob('lib/data/batch_files/Untitled-*.json') + 
                   glob.glob('lib/data/batch_files/Untitled-*.dart') + 
                   glob.glob('lib/data/batch_files/Untitled-*.vb') + 
                   glob.glob('lib/data/batch_files/Untitled-*.jl') +
                   glob.glob('lib/data/batch_files/Untitled-*'))  # Files without extensions
    # Remove duplicates (files with extensions will match both patterns)
    files = list(dict.fromkeys(files))
    
    templates_by_theme = {}
    
    for filepath in files:
        templates = extract_templates_from_file(filepath)
        for template in templates:
            theme = template['theme']
            if theme not in templates_by_theme:
                templates_by_theme[theme] = []
            templates_by_theme[theme].append(template)
    
    # Generate the Dart file
    output_path = 'lib/data/trivia_templates_consolidated.dart'
    generate_dart_file(templates_by_theme, output_path)
    
    print(f"\nConsolidation complete!")
    print(f"Total templates: {sum(len(t) for t in templates_by_theme.values())}")
    print(f"Total themes: {len(templates_by_theme)}")

