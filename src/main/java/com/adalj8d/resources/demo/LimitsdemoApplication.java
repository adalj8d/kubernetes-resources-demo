package com.adalj8d.resources.demo;

import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

import java.util.Random;
import java.util.concurrent.CountDownLatch;

@SpringBootApplication
public class LimitsdemoApplication {

	private static final Logger logger = LoggerFactory.getLogger(LimitsdemoApplication.class);

	public static void main(String[] args) {
		SpringApplication.run(LimitsdemoApplication.class, args);
	}

	@Bean
	public CommandLineRunner monteCarloRunner(MeterRegistry registry) {
		return args -> {
			String numSimulaciones = System.getenv("NUM_SIMULACIONES");
			String memEnv = System.getenv("MEM_MB");
			String threadsEnv = System.getenv("NUM_THREADS");
			String durationEnv = System.getenv("DURATION_SECS");

			Integer cpuIterations = numSimulaciones != null ? Integer.parseInt(numSimulaciones) : null;
			Integer memMB = memEnv != null ? Integer.parseInt(memEnv) : null;
			int numThreads = threadsEnv != null ? Integer.parseInt(threadsEnv) : 1;
			int durationSecs = durationEnv != null ? Integer.parseInt(durationEnv) : 60;

			if (cpuIterations == null && memMB == null) {
				logger.info("No se configuró CPU_ITERATIONS ni MEM_MB. Nada que hacer.");
				return;
			}

			CountDownLatch latch = new CountDownLatch(numThreads);

			for (int t = 0; t < numThreads; t++) {
				new Thread(() -> {

					long startGlobal = System.currentTimeMillis();
					long endTime = startGlobal + durationSecs * 1000L;
					int totalIterations = 0;

					logger.info("Thread {}: Iniciando cálculo montecarlo por {} segundos", Thread.currentThread().getName(), durationSecs);

					while (System.currentTimeMillis() < endTime) {

						//si hay definición de memoria, cada iteración incrementa su uso.
						byte[][] mem = null;
						if (memMB != null) {
							mem = new byte[memMB][1024 * 1024];
							logger.info("Thread {}: Reservados {} MB de memoria.", Thread.currentThread().getName(), memMB);
						}

						if (cpuIterations != null) {
							long start = System.currentTimeMillis();
							Random rand = new Random();

							int inside = 0;
							for (int i = 0; i < cpuIterations; i++) {
								double x = rand.nextDouble();
								double y = rand.nextDouble();
								if (x * x + y * y <= 1.0) inside++;
							}
							double pi = 4.0 * inside / cpuIterations;
							long elapsed = System.currentTimeMillis() - start;
							logger.info("Thread {}: PI estimado: {} en {} millisegundos ", Thread.currentThread().getName(), pi, elapsed);
						}
						totalIterations++;
					}
					long elapsed = System.currentTimeMillis() - startGlobal;

					logger.info("Thread {}: Iteraciones totales: {}", Thread.currentThread().getName(), totalIterations);
					logger.info("Thread {}: Tiempo total (ms): {}", Thread.currentThread().getName(), elapsed);

					latch.countDown();
				}, "MonteCarlo-" + t).start();

				try {
					logger.info("Thread {}: Esperando 1 seg para siguiente hilo: {} de {}", Thread.currentThread().getName(), t, numThreads);
					Thread.sleep(1000);
				} catch (InterruptedException ignored) {}
			}
			latch.await();
		};
	}
}