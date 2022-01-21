#include <algorithm>

#include "flamegpu/flamegpu.h"
#include "common.cuh"

namespace {

FLAMEGPU_AGENT_FUNCTION(output_message, flamegpu::MessageNone, flamegpu::MessageSpatial3D) {
    FLAMEGPU->message_out.setVariable<int>("id", FLAMEGPU->getVariable<int>("id"));
    FLAMEGPU->message_out.setLocation(
        FLAMEGPU->getVariable<float>("x"),
        FLAMEGPU->getVariable<float>("y"),
        FLAMEGPU->getVariable<float>("z"));
    return flamegpu::ALIVE;
}
FLAMEGPU_AGENT_FUNCTION(move, flamegpu::MessageSpatial3D, flamegpu::MessageNone) {
    const int ID = FLAMEGPU->getVariable<int>("id");
    const float REPULSE_FACTOR = FLAMEGPU->environment.getProperty<float>("repulse");
    const float RADIUS = FLAMEGPU->message_in.radius();
    float fx = 0.0;
    float fy = 0.0;
    float fz = 0.0;
    const float x1 = FLAMEGPU->getVariable<float>("x");
    const float y1 = FLAMEGPU->getVariable<float>("y");
    const float z1 = FLAMEGPU->getVariable<float>("z");
    int count = 0;
    int messageCount = 0;
    for (const auto &message : FLAMEGPU->message_in(x1, y1, z1)) {
        if (message.getVariable<int>("id") != ID) {
            const float x2 = message.getVariable<float>("x");
            const float y2 = message.getVariable<float>("y");
            const float z2 = message.getVariable<float>("z");
            float x21 = x2 - x1;
            float y21 = y2 - y1;
            float z21 = z2 - z1;
            const float separation = cbrt(x21*x21 + y21*y21 + z21*z21);
            if (separation < RADIUS && separation > 0.0f) {
                float k = sinf((separation / RADIUS)*3.141*-2)*REPULSE_FACTOR;
                // Normalise without recalculating separation
                x21 /= separation;
                y21 /= separation;
                z21 /= separation;
                fx += k * x21;
                fy += k * y21;
                fz += k * z21;
                count++;
            }
        }
        messageCount++;
    }
    fx /= count > 0 ? count : 1;
    fy /= count > 0 ? count : 1;
    fz /= count > 0 ? count : 1;
    FLAMEGPU->setVariable<float>("x", x1 + fx);
    FLAMEGPU->setVariable<float>("y", y1 + fy);
    FLAMEGPU->setVariable<float>("z", z1 + fz);
    FLAMEGPU->setVariable<float>("drift", cbrt(fx*fx + fy*fy + fz*fz));
    float totalMessageCount = FLAMEGPU->getVariable<float>("totalMessageCount");
    FLAMEGPU->setVariable<float>("totalMessageCount", totalMessageCount + messageCount);
    FLAMEGPU->setVariable<float>("stepMessageCount", messageCount);
    return flamegpu::ALIVE;
}

}  // namespace

// Run an individual simulation, using 
void run_circles_spatial3D(const RunSimulationInputs runInputs, RunSimulationOutputs &runOutputs){
    flamegpu::ModelDescription model("circles_spatial3D");
    // Calculate environment bounds.
    const float ENV_WIDTH = runInputs.ENV_WIDTH;
    const float ENV_MIN = -0.5f * ENV_WIDTH;
    const float ENV_MAX = ENV_MIN + ENV_WIDTH;
    // Compute the actual density and return it.
    runOutputs.agentDensity = runInputs.AGENT_COUNT / (ENV_WIDTH * ENV_WIDTH * ENV_WIDTH);
    {   // Location message
        flamegpu::MessageSpatial3D::Description &message = model.newMessage<flamegpu::MessageSpatial3D>("location");
        message.newVariable<int>("id");
        message.setRadius(runInputs.COMM_RADIUS);
        message.setMin(ENV_MIN, ENV_MIN, ENV_MIN);
        message.setMax(ENV_MAX, ENV_MAX, ENV_MAX);
    }
    {   // Circle agent
        flamegpu::AgentDescription &agent = model.newAgent("Circle");
        agent.newVariable<int>("id");
        agent.newVariable<float>("x");
        agent.newVariable<float>("y");
        agent.newVariable<float>("z");
        agent.newVariable<float>("totalMessageCount", 0.f);
        agent.newVariable<float>("stepMessageCount", 0.f);
        agent.newVariable<float>("drift");  // Store the distance moved here, for validation
        agent.newFunction("output_message", output_message).setMessageOutput("location");
        agent.newFunction("move", move).setMessageInput("location");
    }

    // Global environment variables.
    {
        flamegpu::EnvironmentDescription &env = model.Environment();
        env.newProperty("repulse", ENV_REPULSE);
    }

    // Organise the model. 

    {   // Layer #1
        flamegpu::LayerDescription &layer = model.newLayer();
        layer.addAgentFunction(output_message);
    }
    {   // Layer #2
        flamegpu::LayerDescription &layer = model.newLayer();
        layer.addAgentFunction(move);
    }

    // create step logging for drift and message data
    flamegpu::StepLoggingConfig step_log_cfg(model);
    {
        step_log_cfg.setFrequency(1);
        step_log_cfg.agent("Circle").logMean<float>("drift");
        step_log_cfg.agent("Circle").logMean<float>("stepMessageCount");
    }

    // create exit log
    flamegpu::StepLoggingConfig exit_log_cfg(model);
    {
        exit_log_cfg.agent("Circle").logMean<float>("totalMessageCount");
    }

    // Create the simulation object
    flamegpu::CUDASimulation simulation(model);

#ifdef VISUALISATION
    flamegpu::visualiser::ModelVis& visualisation = simulation.getVisualisation();
    {
        visualisation.setInitialCameraLocation(ENV_WIDTH, ENV_WIDTH, ENV_WIDTH);
        visualisation.setInitialCameraTarget(0.0f, 0.0f, 0.0f);
        visualisation.setCameraSpeed(0.001f * ENV_WIDTH);
        visualisation.setViewClips(0.1f, 5000);
        visualisation.setClearColor(1.0f, 1.0f, 1.0f);
        visualisation.setFPSColor(0.0f, 0.0f, 0.0f);
        visualisation.setBeginPaused(true);
        auto& agt = visualisation.addAgent("Circle");
        agt.setModel(flamegpu::visualiser::Stock::Models::SPHERE);
        agt.setModelScale(0.1f);
    }
    visualisation.activate();
#endif


    // Set config configuraiton properties 
    simulation.SimulationConfig().timing = false;
    simulation.SimulationConfig().verbose = false;
    simulation.SimulationConfig().random_seed = runInputs.SEED;
    simulation.SimulationConfig().steps = runInputs.STEPS;
    simulation.CUDAConfig().device_id = runInputs.CUDA_DEVICE;

    // Generate the initial population
    std::mt19937_64 rng(runInputs.SEED);
    std::uniform_real_distribution<float> dist(ENV_MIN, ENV_MAX);
    flamegpu::AgentVector population(model.Agent("Circle"), runInputs.AGENT_COUNT);
    for (unsigned int i = 0; i < runInputs.AGENT_COUNT; i++) {
        flamegpu::AgentVector::Agent instance = population[i];
        instance.setVariable<int>("id", i);
        instance.setVariable<float>("x", dist(rng));
        instance.setVariable<float>("y", dist(rng));
        instance.setVariable<float>("z", dist(rng));
    }

    // Set the population for the simulation.
    simulation.setPopulationData(population);

    //attach loggin configs
    simulation.setStepLog(step_log_cfg);
    simulation.setExitLog(exit_log_cfg);

    // Execute 
    simulation.simulate();

#ifdef VISUALISATION
    visualisation.join();
#endif

    // get step log data
    runOutputs.drift_per_step = std::make_shared<std::vector<double>>();
    runOutputs.messages_per_step = std::make_shared<std::vector<double>>();
    flamegpu::RunLog run_log = simulation.getRunLog();
    std::list<flamegpu::LogFrame> step_log = run_log.getStepLog();
    for (auto& log : step_log) {
        runOutputs.drift_per_step->push_back(log.getAgent("Circle").getMean("drift"));
        runOutputs.messages_per_step->push_back(log.getAgent("Circle").getMean("stepMessageCount"));
    }

    // get timing data
    std::vector<double> s_steps = simulation.getElapsedTimeSteps();
    runOutputs.s_per_step = std::make_shared<std::vector<double>>(s_steps.begin(), s_steps.end());
    runOutputs.s_stepMean = std::accumulate(s_steps.begin(), s_steps.end(), 0.0) / simulation.getStepCounter();

    // get message count from exit log
    flamegpu::LogFrame exit_log = run_log.getExitLog();
    runOutputs.mean_messageCount = exit_log.getAgent("Circle").getMean("totalMessageCount") / (double)runInputs.STEPS;
}
