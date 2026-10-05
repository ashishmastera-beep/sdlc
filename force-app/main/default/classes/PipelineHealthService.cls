/**
 * Pipeline smoke test (SDLC-2). Proves PR validation, coverage gate and release work end to end.
 * Safe to delete once the pipeline is trusted.
 */
public with sharing class PipelineHealthService {
  public static final String DEFAULT_NAME = 'pipeline';

  /**
   * Returns a greeting for the given name, falling back to DEFAULT_NAME when blank.
   */
  public static String greet(String name) {
    String who = String.isBlank(name) ? DEFAULT_NAME : name.trim();
    return 'Hello, ' + who + '!';
  }
}
