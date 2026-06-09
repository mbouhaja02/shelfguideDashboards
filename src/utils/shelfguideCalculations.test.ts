import { describe, expect, it } from 'vitest';
import {
  getComplianceScore,
  getFillRate,
  getLossRate,
  getMainIssue,
  getPriorityLevel,
  getSeverityLevel,
} from './shelfguideCalculations';

describe('ShelfGuide calculations', () => {
  it('uses weighted profitability before fallback calculations', () => {
    expect(getComplianceScore({
      weighted_profitability_percent: 91,
      shelf_profitability_percent: 70,
      empty_ratio_percent: 30,
    })).toBe(91);
  });

  it('uses shelf profitability when weighted profitability is absent', () => {
    expect(getComplianceScore({
      shelf_profitability_percent: 84,
      empty_ratio_percent: 30,
    })).toBe(84);
  });

  it('calculates and clamps fallback compliance', () => {
    expect(getComplianceScore({
      empty_ratio_percent: 10,
      back_ratio_percent: 5,
    })).toBeCloseTo(91.4);
    expect(getComplianceScore({
      empty_ratio_percent: 200,
      back_ratio_percent: 200,
    })).toBe(0);
  });

  it('calculates fill and loss rates', () => {
    const row = { empty_ratio_percent: 12, back_ratio_percent: 8 };
    expect(getFillRate(row)).toBe(88);
    expect(getLossRate(row)).toBeCloseTo(11);
  });

  it('uses explicit weighted and shelf loss values first', () => {
    expect(getLossRate({
      weighted_loss_percent: 17,
      shelf_loss_percent: 10,
    })).toBe(17);
    expect(getLossRate({ shelf_loss_percent: 10 })).toBe(10);
  });

  it('classifies critical severity from business thresholds', () => {
    expect(getSeverityLevel({
      raw_products_detected: 10,
      products_analyzed: 10,
      empty_ratio_percent: 18,
    })).toBe('Critique');
    expect(getSeverityLevel({
      weighted_profitability_percent: 64,
      raw_products_detected: 10,
      products_analyzed: 10,
    })).toBe('Critique');
  });

  it('classifies medium and healthy severity', () => {
    expect(getSeverityLevel({
      raw_products_detected: 10,
      products_analyzed: 10,
      empty_ratio_percent: 8,
    })).toBe('Moyen');
    expect(getSeverityLevel({
      raw_products_detected: 10,
      products_analyzed: 10,
      empty_ratio_percent: 1,
      back_ratio_percent: 1,
    })).toBe('Bon');
  });

  it('derives high, medium and low priorities', () => {
    expect(getPriorityLevel({
      raw_products_detected: 10,
      products_analyzed: 10,
      empty_ratio_percent: 15,
    })).toBe('Haute');
    expect(getPriorityLevel({
      raw_products_detected: 10,
      products_analyzed: 10,
      empty_ratio_percent: 5,
    })).toBe('Moyenne');
    expect(getPriorityLevel({
      raw_products_detected: 10,
      products_analyzed: 10,
      empty_ratio_percent: 1,
      back_ratio_percent: 1,
    })).toBe('Faible');
  });

  it('keeps issue precedence deterministic', () => {
    expect(getMainIssue({
      raw_products_detected: 0,
      products_analyzed: 0,
      empty_ratio_percent: 20,
    })).toBe('Audit incomplet');
    expect(getMainIssue({
      raw_products_detected: 10,
      products_analyzed: 10,
      empty_ratio_percent: 10,
      back_ratio_percent: 20,
    })).toBe('Rupture visible');
    expect(getMainIssue({
      raw_products_detected: 10,
      products_analyzed: 10,
      empty_ratio_percent: 1,
      back_ratio_percent: 7,
    })).toBe('Mauvaise orientation');
  });
});
