package org.radargun.stages;

import java.util.List;

import org.radargun.DistStageAck;
import org.radargun.StageResult;
import org.radargun.config.Stage;
import org.radargun.stages.lifecycle.LifecycleHelper;
import org.radargun.state.ServiceListener;
import org.radargun.traits.InjectTrait;
import org.radargun.traits.Lifecycle;
import org.radargun.utils.Utils;

/**
 * This stage is the last stage that gets {@link org.radargun.traits.Trait Traits} injected
 * and which is ran in the {@link org.radargun.Slave.ScenarioRunner} thread.
 * It should destroy the service - afterwards, no more references to service should be held.
 *
 * @author Radim Vansa &lt;rvansa@redhat.com&gt;
 */
@Stage(internal = true, doc = "DO NOT USE DIRECTLY. This stage is automatically inserted after the last stage in each scenario.")
public class ScenarioDestroyStage extends InternalDistStage {
   @InjectTrait
   protected Lifecycle lifecycle;

   @Override
   public DistStageAck executeOnSlave() {
      log.info("Scenario finished, destroying...");
      log.info("Memory before cleanup: \n" + Utils.getMemoryInfo());
      try {
         if (lifecycle != null && lifecycle.isRunning()) {
            LifecycleHelper.stop(slaveState, true, false);
            log.info("Service successfully stopped.");
         } else {
            log.info("No service deployed on this slave, nothing to do.");
         }
      } catch (Exception e) {
         return errorResponse("Problems shutting down the slave", e);
      } finally {
         log.trace("Calling destroy hooks");
         for (ServiceListener listener : slaveState.getServiceListeners()) {
            listener.serviceDestroyed();
         }
         //reset the class loader to SystemClassLoader
         Thread.currentThread().setContextClassLoader(getClass().getClassLoader());
         slaveState.reset();
      }
      return successfulResponse();
   }

   @Override
   public StageResult processAckOnMaster(List<DistStageAck> acks) {
      StageResult result = StageResult.SUCCESS;
      for (DistStageAck ack : acks) {
         if (ack.isError()) {
            log.warn("Received error ack " + ack);
            result = errorResult();
         } else {
            if (log.isTraceEnabled()) {
               log.trace("Received success ack " + ack);
            }
         }
      }
      return result;
   }
}
