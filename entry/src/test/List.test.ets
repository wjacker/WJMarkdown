import localUnitTest from './LocalUnit.test';
import hiAgentSseParserTest from './HiAgentSseParser.test';
import markdownParserTest from './MarkdownParser.test';

export default function testsuite() {
  localUnitTest();
  hiAgentSseParserTest();
  markdownParserTest();
}
