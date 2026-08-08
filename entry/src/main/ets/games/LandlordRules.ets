/*
 * 斗地主合法动作与牌型比较。
 * 牌型分类和动作生成思路参考 kwai/DouZero（Apache-2.0），并针对 ArkTS 与本项目数据模型重写。
 */

export enum LandlordPatternType {
  INVALID = 'invalid',
  SINGLE = 'single',
  PAIR = 'pair',
  TRIPLE = 'triple',
  BOMB = 'bomb',
  ROCKET = 'rocket',
  TRIPLE_SINGLE = 'tripleSingle',
  TRIPLE_PAIR = 'triplePair',
  STRAIGHT = 'straight',
  PAIR_STRAIGHT = 'pairStraight',
  AIRPLANE = 'airplane',
  AIRPLANE_SINGLE = 'airplaneSingle',
  AIRPLANE_PAIR = 'airplanePair',
  FOUR_TWO = 'fourTwo',
  FOUR_TWO_PAIR = 'fourTwoPair'
}

export class LandlordPattern {
  public type: LandlordPatternType = LandlordPatternType.INVALID;
  public mainRank: number = -1;
  public length: number = 0;
  public sequenceLength: number = 0;
}

export class LandlordRules {
  public static rank(card: string): number {
    if (card === '小王') {
      return 13;
    }
    if (card === '大王') {
      return 14;
    }
    const ranks: string[] = ['3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A', '2'];
    return ranks.indexOf(card.substring(1));
  }

  public static analyze(cards: string[]): LandlordPattern {
    const result: LandlordPattern = new LandlordPattern();
    result.length = cards.length;
    if (cards.length === 0) {
      return result;
    }
    const counts: number[] = LandlordRules.emptyCounts();
    for (let index: number = 0; index < cards.length; index += 1) {
      const rank: number = LandlordRules.rank(cards[index]);
      if (rank < 0) {
        return result;
      }
      counts[rank] += 1;
    }
    if (cards.length === 1) {
      return LandlordRules.pattern(LandlordPatternType.SINGLE, LandlordRules.highestRank(counts), 1, 1);
    }
    if (cards.length === 2 && counts[13] === 1 && counts[14] === 1) {
      return LandlordRules.pattern(LandlordPatternType.ROCKET, 14, 2, 1);
    }
    const pairs: number[] = LandlordRules.ranksWithExactCount(counts, 2);
    const triples: number[] = LandlordRules.ranksWithExactCount(counts, 3);
    const fours: number[] = LandlordRules.ranksWithExactCount(counts, 4);
    if (cards.length === 2 && pairs.length === 1) {
      return LandlordRules.pattern(LandlordPatternType.PAIR, pairs[0], 2, 1);
    }
    if (cards.length === 3 && triples.length === 1) {
      return LandlordRules.pattern(LandlordPatternType.TRIPLE, triples[0], 3, 1);
    }
    if (cards.length === 4 && fours.length === 1) {
      return LandlordRules.pattern(LandlordPatternType.BOMB, fours[0], 4, 1);
    }
    if (cards.length === 4 && triples.length === 1) {
      return LandlordRules.pattern(LandlordPatternType.TRIPLE_SINGLE, triples[0], 4, 1);
    }
    if (cards.length === 5 && triples.length === 1 && pairs.length === 1) {
      return LandlordRules.pattern(LandlordPatternType.TRIPLE_PAIR, triples[0], 5, 1);
    }

    const singles: number[] = LandlordRules.ranksWithExactCount(counts, 1);
    if (cards.length >= 5 && singles.length === cards.length && LandlordRules.isConsecutive(singles) &&
      singles[singles.length - 1] <= 11) {
      return LandlordRules.pattern(LandlordPatternType.STRAIGHT, singles[singles.length - 1],
        cards.length, singles.length);
    }
    if (cards.length >= 6 && cards.length % 2 === 0 && pairs.length * 2 === cards.length &&
      LandlordRules.isConsecutive(pairs) && pairs[pairs.length - 1] <= 11) {
      return LandlordRules.pattern(LandlordPatternType.PAIR_STRAIGHT, pairs[pairs.length - 1],
        cards.length, pairs.length);
    }
    if (cards.length >= 6 && cards.length % 3 === 0 && triples.length * 3 === cards.length &&
      LandlordRules.isConsecutive(triples) && triples[triples.length - 1] <= 11) {
      return LandlordRules.pattern(LandlordPatternType.AIRPLANE, triples[triples.length - 1],
        cards.length, triples.length);
    }

    if (cards.length >= 8 && cards.length % 4 === 0) {
      const tripleCount: number = cards.length / 4;
      const airplaneHigh: number = LandlordRules.findAirplaneCore(counts, tripleCount, false);
      if (airplaneHigh >= 0) {
        return LandlordRules.pattern(LandlordPatternType.AIRPLANE_SINGLE, airplaneHigh,
          cards.length, tripleCount);
      }
    }
    if (cards.length >= 10 && cards.length % 5 === 0) {
      const tripleCount: number = cards.length / 5;
      const airplaneHigh: number = LandlordRules.findAirplaneCore(counts, tripleCount, true);
      if (airplaneHigh >= 0) {
        return LandlordRules.pattern(LandlordPatternType.AIRPLANE_PAIR, airplaneHigh,
          cards.length, tripleCount);
      }
    }
    if (cards.length === 6 && fours.length === 1) {
      return LandlordRules.pattern(LandlordPatternType.FOUR_TWO, fours[0], 6, 1);
    }
    if (cards.length === 8 && (fours.length === 1 && pairs.length === 2 || fours.length === 2)) {
      return LandlordRules.pattern(LandlordPatternType.FOUR_TWO_PAIR,
        fours[fours.length - 1], 8, 1);
    }
    return result;
  }

  public static canBeat(next: LandlordPattern, previous: LandlordPattern): boolean {
    if (next.type === LandlordPatternType.INVALID || previous.type === LandlordPatternType.INVALID) {
      return false;
    }
    if (next.type === LandlordPatternType.ROCKET) {
      return previous.type !== LandlordPatternType.ROCKET;
    }
    if (previous.type === LandlordPatternType.ROCKET) {
      return false;
    }
    if (next.type === LandlordPatternType.BOMB && previous.type !== LandlordPatternType.BOMB) {
      return true;
    }
    if (next.type !== previous.type) {
      return false;
    }
    return next.length === previous.length && next.sequenceLength === previous.sequenceLength &&
      next.mainRank > previous.mainRank;
  }

  public static suggest(hand: string[], previousCards: string[], preferLongLead: boolean = false): number[] {
    const candidates: number[][] = LandlordRules.generateCandidates(hand);
    const previous: LandlordPattern = LandlordRules.analyze(previousCards);
    let best: number[] = [];
    let bestPattern: LandlordPattern = new LandlordPattern();
    for (let index: number = 0; index < candidates.length; index += 1) {
      const candidate: number[] = candidates[index];
      const cards: string[] = LandlordRules.cardsAt(hand, candidate);
      const pattern: LandlordPattern = LandlordRules.analyze(cards);
      if (pattern.type === LandlordPatternType.INVALID) {
        continue;
      }
      if (previousCards.length > 0 && !LandlordRules.canBeat(pattern, previous)) {
        continue;
      }
      if (best.length === 0 || LandlordRules.isBetterSuggestion(pattern, bestPattern,
        previousCards.length === 0, preferLongLead)) {
        best = candidate.slice();
        bestPattern = pattern;
      }
    }
    return best;
  }

  public static cardsAt(hand: string[], indexes: number[]): string[] {
    const cards: string[] = [];
    for (let index: number = 0; index < indexes.length; index += 1) {
      if (indexes[index] >= 0 && indexes[index] < hand.length) {
        cards.push(hand[indexes[index]]);
      }
    }
    return cards;
  }

  private static generateCandidates(hand: string[]): number[][] {
    const groups: number[][] = LandlordRules.rankGroups(hand);
    const candidates: number[][] = [];
    const keys: string[] = [];
    for (let rank: number = 0; rank < groups.length; rank += 1) {
      if (groups[rank].length >= 1) {
        LandlordRules.addCandidate(candidates, keys, [groups[rank][0]]);
      }
      if (groups[rank].length >= 2) {
        LandlordRules.addCandidate(candidates, keys, groups[rank].slice(0, 2));
      }
      if (groups[rank].length >= 3) {
        LandlordRules.addCandidate(candidates, keys, groups[rank].slice(0, 3));
      }
      if (groups[rank].length === 4) {
        LandlordRules.addCandidate(candidates, keys, groups[rank].slice(0, 4));
      }
    }
    if (groups[13].length > 0 && groups[14].length > 0) {
      LandlordRules.addCandidate(candidates, keys, [groups[13][0], groups[14][0]]);
    }

    for (let tripleRank: number = 0; tripleRank <= 12; tripleRank += 1) {
      if (groups[tripleRank].length < 3) {
        continue;
      }
      const core: number[] = groups[tripleRank].slice(0, 3);
      for (let singleRank: number = 0; singleRank < groups.length; singleRank += 1) {
        if (singleRank !== tripleRank && groups[singleRank].length > 0) {
          LandlordRules.addCandidate(candidates, keys, core.concat([groups[singleRank][0]]));
        }
        if (singleRank !== tripleRank && groups[singleRank].length >= 2) {
          LandlordRules.addCandidate(candidates, keys, core.concat(groups[singleRank].slice(0, 2)));
        }
      }
    }

    LandlordRules.addSequences(groups, 1, 5, candidates, keys);
    LandlordRules.addSequences(groups, 2, 3, candidates, keys);
    LandlordRules.addSequences(groups, 3, 2, candidates, keys);
    LandlordRules.addAirplanes(groups, hand.length, candidates, keys);
    LandlordRules.addFourWithTwo(groups, hand.length, candidates, keys);
    return candidates;
  }

  private static addSequences(groups: number[][], repeat: number, minimumRanks: number,
    candidates: number[][], keys: string[]): void {
    for (let start: number = 0; start <= 11; start += 1) {
      if (groups[start].length < repeat) {
        continue;
      }
      const indexes: number[] = [];
      for (let end: number = start; end <= 11 && groups[end].length >= repeat; end += 1) {
        for (let copy: number = 0; copy < repeat; copy += 1) {
          indexes.push(groups[end][copy]);
        }
        if (end - start + 1 >= minimumRanks) {
          LandlordRules.addCandidate(candidates, keys, indexes);
        }
      }
    }
  }

  private static addAirplanes(groups: number[][], handSize: number,
    candidates: number[][], keys: string[]): void {
    for (let start: number = 0; start <= 10; start += 1) {
      const core: number[] = [];
      const coreRanks: number[] = [];
      for (let end: number = start; end <= 11 && groups[end].length >= 3; end += 1) {
        coreRanks.push(end);
        core.push(groups[end][0]);
        core.push(groups[end][1]);
        core.push(groups[end][2]);
        const tripleCount: number = end - start + 1;
        if (tripleCount < 2) {
          continue;
        }
        LandlordRules.addCandidate(candidates, keys, core);
        const remaining: number[] = [];
        const pairRanks: number[] = [];
        for (let rank: number = 0; rank < groups.length; rank += 1) {
          if (coreRanks.indexOf(rank) >= 0) {
            continue;
          }
          for (let item: number = 0; item < groups[rank].length; item += 1) {
            remaining.push(groups[rank][item]);
          }
          if (groups[rank].length >= 2) {
            pairRanks.push(rank);
          }
        }
        const singleWings: number[][] = LandlordRules.choose(remaining, tripleCount, 5000);
        for (let choiceIndex: number = 0; choiceIndex < singleWings.length; choiceIndex += 1) {
          LandlordRules.addCandidate(candidates, keys, core.concat(singleWings[choiceIndex]));
        }
        const pairChoices: number[][] = LandlordRules.choose(pairRanks, tripleCount, 1000);
        for (let choiceIndex: number = 0; choiceIndex < pairChoices.length; choiceIndex += 1) {
          const wingIndexes: number[] = [];
          for (let rankIndex: number = 0; rankIndex < pairChoices[choiceIndex].length; rankIndex += 1) {
            const rank: number = pairChoices[choiceIndex][rankIndex];
            wingIndexes.push(groups[rank][0]);
            wingIndexes.push(groups[rank][1]);
          }
          LandlordRules.addCandidate(candidates, keys, core.concat(wingIndexes));
        }
        if (core.length >= handSize) {
          break;
        }
      }
    }
  }

  private static addFourWithTwo(groups: number[][], handSize: number,
    candidates: number[][], keys: string[]): void {
    for (let fourRank: number = 0; fourRank <= 12; fourRank += 1) {
      if (groups[fourRank].length !== 4) {
        continue;
      }
      const core: number[] = groups[fourRank].slice(0, 4);
      const remaining: number[] = [];
      const pairRanks: number[] = [];
      for (let rank: number = 0; rank < groups.length; rank += 1) {
        if (rank === fourRank) {
          continue;
        }
        for (let item: number = 0; item < groups[rank].length; item += 1) {
          remaining.push(groups[rank][item]);
        }
        if (groups[rank].length >= 2) {
          pairRanks.push(rank);
        }
      }
      const singleChoices: number[][] = LandlordRules.choose(remaining, 2, 500);
      for (let choiceIndex: number = 0; choiceIndex < singleChoices.length; choiceIndex += 1) {
        LandlordRules.addCandidate(candidates, keys, core.concat(singleChoices[choiceIndex]));
      }
      const pairChoices: number[][] = LandlordRules.choose(pairRanks, 2, 200);
      for (let choiceIndex: number = 0; choiceIndex < pairChoices.length; choiceIndex += 1) {
        const firstRank: number = pairChoices[choiceIndex][0];
        const secondRank: number = pairChoices[choiceIndex][1];
        LandlordRules.addCandidate(candidates, keys,
          core.concat(groups[firstRank].slice(0, 2)).concat(groups[secondRank].slice(0, 2)));
      }
      if (core.length >= handSize) {
        return;
      }
    }
  }

  private static addCandidate(candidates: number[][], keys: string[], indexes: number[]): void {
    const sorted: number[] = indexes.slice();
    sorted.sort((left: number, right: number): number => left - right);
    const key: string = sorted.join(',');
    if (keys.indexOf(key) < 0) {
      keys.push(key);
      candidates.push(sorted);
    }
  }

  private static choose(values: number[], count: number, limit: number): number[][] {
    const result: number[][] = [];
    const current: number[] = [];
    LandlordRules.chooseFrom(values, count, 0, current, result, limit);
    return result;
  }

  private static chooseFrom(values: number[], count: number, start: number, current: number[],
    result: number[][], limit: number): void {
    if (result.length >= limit) {
      return;
    }
    if (current.length === count) {
      result.push(current.slice());
      return;
    }
    const required: number = count - current.length;
    for (let index: number = start; index <= values.length - required; index += 1) {
      current.push(values[index]);
      LandlordRules.chooseFrom(values, count, index + 1, current, result, limit);
      current.pop();
      if (result.length >= limit) {
        return;
      }
    }
  }

  private static rankGroups(hand: string[]): number[][] {
    const groups: number[][] = [];
    for (let rank: number = 0; rank < 15; rank += 1) {
      groups.push([]);
    }
    for (let index: number = 0; index < hand.length; index += 1) {
      const rank: number = LandlordRules.rank(hand[index]);
      if (rank >= 0) {
        groups[rank].push(index);
      }
    }
    return groups;
  }

  private static findAirplaneCore(counts: number[], tripleCount: number, requirePairs: boolean): number {
    for (let start: number = 0; start + tripleCount - 1 <= 11; start += 1) {
      let valid: boolean = true;
      const remaining: number[] = counts.slice();
      for (let offset: number = 0; offset < tripleCount; offset += 1) {
        if (counts[start + offset] !== 3) {
          valid = false;
          break;
        }
        remaining[start + offset] = 0;
      }
      if (!valid) {
        continue;
      }
      let remainingCards: number = 0;
      let pairRanks: number = 0;
      for (let rank: number = 0; rank < remaining.length; rank += 1) {
        remainingCards += remaining[rank];
        if (remaining[rank] === 2) {
          pairRanks += 1;
        }
      }
      if (!requirePairs && remainingCards === tripleCount ||
        requirePairs && remainingCards === tripleCount * 2 && pairRanks === tripleCount) {
        return start + tripleCount - 1;
      }
    }
    return -1;
  }

  private static isBetterSuggestion(next: LandlordPattern, current: LandlordPattern,
    leading: boolean, preferLongLead: boolean): boolean {
    const nextBomb: boolean = next.type === LandlordPatternType.BOMB || next.type === LandlordPatternType.ROCKET;
    const currentBomb: boolean = current.type === LandlordPatternType.BOMB ||
      current.type === LandlordPatternType.ROCKET;
    if (nextBomb !== currentBomb) {
      return !nextBomb;
    }
    if (leading && preferLongLead && next.length !== current.length) {
      return next.length > current.length;
    }
    if (leading && !preferLongLead && next.length !== current.length) {
      return next.length < current.length;
    }
    if (next.mainRank !== current.mainRank) {
      return next.mainRank < current.mainRank;
    }
    return next.length < current.length;
  }

  private static pattern(type: LandlordPatternType, mainRank: number,
    length: number, sequenceLength: number): LandlordPattern {
    const result: LandlordPattern = new LandlordPattern();
    result.type = type;
    result.mainRank = mainRank;
    result.length = length;
    result.sequenceLength = sequenceLength;
    return result;
  }

  private static emptyCounts(): number[] {
    const counts: number[] = [];
    for (let index: number = 0; index < 15; index += 1) {
      counts.push(0);
    }
    return counts;
  }

  private static ranksWithExactCount(counts: number[], count: number): number[] {
    const ranks: number[] = [];
    for (let rank: number = 0; rank < counts.length; rank += 1) {
      if (counts[rank] === count) {
        ranks.push(rank);
      }
    }
    return ranks;
  }

  private static highestRank(counts: number[]): number {
    for (let rank: number = counts.length - 1; rank >= 0; rank -= 1) {
      if (counts[rank] > 0) {
        return rank;
      }
    }
    return -1;
  }

  private static isConsecutive(ranks: number[]): boolean {
    if (ranks.length === 0) {
      return false;
    }
    for (let index: number = 1; index < ranks.length; index += 1) {
      if (ranks[index] !== ranks[index - 1] + 1) {
        return false;
      }
    }
    return true;
  }
}
