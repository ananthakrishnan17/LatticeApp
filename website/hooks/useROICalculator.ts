import { useMemo } from "react";

type ROIInputs = {
  monthlyTransactions: number;
  avgOrderValue: number;
  billingStaff: number;
  manualHoursPerDay: number;
};

type ROIResults = {
  monthlyTimeSaved: number;
  annualCostSavings: number;
  roiFirstYear: number;
  breakEvenWeeks: number;
};

const HOURLY_RATE = 150;
const ANNUAL_PLAN_COST = 12000;

export function useROICalculator(inputs: ROIInputs): ROIResults {
  return useMemo(() => {
    const {
      billingStaff,
      manualHoursPerDay,
      monthlyTransactions,
      avgOrderValue,
    } = inputs;
    const monthlyTimeSaved = billingStaff * manualHoursPerDay * 0.7 * 30;
    const annualCostSavings = monthlyTimeSaved * 12 * HOURLY_RATE;
    const roiFirstYear =
      ANNUAL_PLAN_COST > 0
        ? Math.round(
            ((annualCostSavings - ANNUAL_PLAN_COST) / ANNUAL_PLAN_COST) * 100,
          )
        : 0;
    const weeklyRevenue = (monthlyTransactions * avgOrderValue) / 4;
    const breakEvenWeeks =
      weeklyRevenue > 0
        ? Math.max(
            1,
            Math.round((ANNUAL_PLAN_COST / 52) / (weeklyRevenue * 0.01)),
          )
        : 4;

    return {
      monthlyTimeSaved: Math.round(monthlyTimeSaved),
      annualCostSavings: Math.round(annualCostSavings),
      roiFirstYear,
      breakEvenWeeks,
    };
  }, [inputs]);
}
