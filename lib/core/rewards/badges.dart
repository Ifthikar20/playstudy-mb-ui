import 'package:flutter/material.dart';
import 'rewards_bloc.dart';

/// Snapshot of the values that gate badge unlocks. Built from RewardsState +
/// the learning library count so badges don't need their own persistence.
class BadgeContext {
  final int points;
  final int streak;
  final int rankIndex;
  final int librarySize;
  const BadgeContext({
    required this.points,
    required this.streak,
    required this.rankIndex,
    required this.librarySize,
  });
}

/// An achievement the user can unlock. Pure derivation from BadgeContext —
/// no per-badge state stored on disk.
class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final List<Color> colors;
  final bool Function(BadgeContext ctx) isUnlocked;
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.colors,
    required this.isUnlocked,
  });
}

const _orange = [Color(0xFFFF6B00), Color(0xFFFF2D55)];
const _blue = [Color(0xFF007AFF), Color(0xFF5856D6)];
const _green = [Color(0xFF22C55E), Color(0xFF14B8A6)];
const _purple = [Color(0xFFA855F7), Color(0xFFEC4899)];
const _gold = [Color(0xFFF59E0B), Color(0xFFEF4444)];

final List<Achievement> kAchievements = [
  Achievement(
    id: 'first_set',
    title: 'First Set',
    description: 'Create your first study set',
    emoji: '📚',
    colors: _blue,
    isUnlocked: (c) => c.librarySize >= 1,
  ),
  Achievement(
    id: 'spark',
    title: 'Spark',
    description: 'Start a streak',
    emoji: '✨',
    colors: _orange,
    isUnlocked: (c) => c.streak >= 1,
  ),
  Achievement(
    id: 'centurion',
    title: 'Centurion',
    description: 'Earn 100 points',
    emoji: '💯',
    colors: _green,
    isUnlocked: (c) => c.points >= 100,
  ),
  Achievement(
    id: 'on_fire',
    title: 'On Fire',
    description: 'Hit a 3-day streak',
    emoji: '🔥',
    colors: _orange,
    isUnlocked: (c) => c.streak >= 3,
  ),
  Achievement(
    id: 'curator',
    title: 'Curator',
    description: 'Build 5 study sets',
    emoji: '🗂️',
    colors: _purple,
    isUnlocked: (c) => c.librarySize >= 5,
  ),
  Achievement(
    id: 'week_warrior',
    title: 'Week Warrior',
    description: 'Reach a 7-day streak',
    emoji: '🏆',
    colors: _gold,
    isUnlocked: (c) => c.streak >= 7,
  ),
  Achievement(
    id: 'scholar',
    title: 'Scholar',
    description: 'Climb to Scholar rank',
    emoji: '📖',
    colors: _blue,
    isUnlocked: (c) => c.rankIndex >= 2,
  ),
  Achievement(
    id: 'high_roller',
    title: 'High Roller',
    description: 'Earn 500 points',
    emoji: '💸',
    colors: _green,
    isUnlocked: (c) => c.points >= 500,
  ),
  Achievement(
    id: 'library_builder',
    title: 'Library Builder',
    description: 'Build 10 study sets',
    emoji: '🏛️',
    colors: _purple,
    isUnlocked: (c) => c.librarySize >= 10,
  ),
  Achievement(
    id: 'big_brain',
    title: 'Big Brain',
    description: 'Earn 1,000 points',
    emoji: '🧠',
    colors: _gold,
    isUnlocked: (c) => c.points >= 1000,
  ),
  Achievement(
    id: 'unstoppable',
    title: 'Unstoppable',
    description: 'Hold a 30-day streak',
    emoji: '💎',
    colors: _purple,
    isUnlocked: (c) => c.streak >= 30,
  ),
  Achievement(
    id: 'legend',
    title: 'Legend',
    description: 'Reach Legend rank',
    emoji: '👑',
    colors: _gold,
    isUnlocked: (c) => c.rankIndex >= kRanks.length - 1,
  ),
];

BadgeContext buildBadgeContext({
  required RewardsState rewards,
  required int librarySize,
}) {
  return BadgeContext(
    points: rewards.points,
    streak: rewards.streak,
    rankIndex: rewards.currentRankIndex,
    librarySize: librarySize,
  );
}

int countUnlocked(BadgeContext ctx) =>
    kAchievements.where((a) => a.isUnlocked(ctx)).length;
