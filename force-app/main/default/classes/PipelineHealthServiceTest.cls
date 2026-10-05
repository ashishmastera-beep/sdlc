@IsTest
private class PipelineHealthServiceTest {
  @IsTest
  static void greetsByName() {
    Test.startTest();
    String result = PipelineHealthService.greet('  Ashish ');
    Test.stopTest();
    Assert.areEqual(
      'Hello, Ashish!',
      result,
      'Name should be trimmed and greeted'
    );
  }

  @IsTest
  static void fallsBackWhenBlank() {
    Assert.areEqual(
      'Hello, pipeline!',
      PipelineHealthService.greet(null),
      'Null name uses the default'
    );
    Assert.areEqual(
      'Hello, pipeline!',
      PipelineHealthService.greet('   '),
      'Blank name uses the default'
    );
  }
}
