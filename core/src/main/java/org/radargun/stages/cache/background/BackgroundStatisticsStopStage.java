package org.radargun.stages.cache.background;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.radargun.DistStageAck;
import org.radargun.StageResult;
import org.radargun.config.Property;
import org.radargun.config.Stage;
import org.radargun.reporting.Report;
import org.radargun.stages.AbstractDistStage;
import org.radargun.state.SlaveState;
import org.radargun.utils.Projections;
import org.radargun.utils.Table;

/**
 * @author Radim Vansa &lt;rvansa@redhat.com&gt;
 */
@Stage(doc = "Stop Statistics and return collected statistics to master.")
public class BackgroundStatisticsStopStage extends AbstractDistStage {

   @Property(doc = "Name of the test used for reports. Default is 'BackgroundStats'.")
   private String testName = "BackgroundStats";

   @Override
   public DistStageAck executeOnSlave() {
      try {
         BackgroundOpsManager instance = BackgroundOpsManager.getInstance(slaveState);
         if (instance != null) {
            instance.stopStats();
            return new StatisticsAck(slaveState, instance.getStats());
         } else {
            return errorResponse("No " + BackgroundOpsManager.NAME);
         }
      } catch (Exception e) {
         return errorResponse("Error while stopping background statistics", e);
      }
   }

   @Override
   public StageResult processAckOnMaster(List<DistStageAck> acks) {
      StageResult res = super.processAckOnMaster(acks);
      if (res.isError()) return res;
      if (testName == null || testName.isEmpty()) {
         log.warn("No test name - results are not recorded");
         return StageResult.SUCCESS;
      } else if (testName.equalsIgnoreCase("warmup")) {
         log.info("This test was executed as a warmup");
         return StageResult.SUCCESS;
      }
      Report report = masterState.getReport();
      Report.Test test = report.createTest(testName, null, false);
      Table<Integer, Integer, Long> cacheSizes = new Table<Integer, Integer, Long>();
      for (StatisticsAck ack : Projections.instancesOf(acks, StatisticsAck.class)) {
         int i = 0;
         for (BackgroundOpsManager.IterationStats stats : ack.iterations) {
            test.addStatistics(i, ack.getSlaveIndex(), stats.statistics);
            cacheSizes.put(ack.getSlaveIndex(), i, stats.cacheSize);
            ++i;
         }
      }
      for (int iteration : cacheSizes.columnKeys()) {
         Map<Integer, Report.SlaveResult> slaveResults = new HashMap<Integer, Report.SlaveResult>();
         long min = Long.MAX_VALUE, max = Long.MIN_VALUE;
         for (Map.Entry<Integer, Long> iterationData : cacheSizes.getColumn(iteration).entrySet()) {
            slaveResults.put(iterationData.getKey(), new Report.SlaveResult(String.valueOf(iterationData.getValue()), false));
            min = Math.min(min, iterationData.getValue());
            max = Math.max(max, iterationData.getValue());
         }
         Report.TestResult result = new Report.TestResult(BackgroundOpsManager.CACHE_SIZE, slaveResults, min < max ? String.format("%d .. %d", min, max) : "-", false);
         test.addResult(iteration, result);
      }
      return StageResult.SUCCESS;
   }

   private static class StatisticsAck extends DistStageAck {
      public final List<BackgroundOpsManager.IterationStats> iterations;

      private StatisticsAck(SlaveState slaveState, List<BackgroundOpsManager.IterationStats> iterations) {
         super(slaveState);
         this.iterations = iterations;
      }
   }
}
