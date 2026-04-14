export class AgentImageAttachment {
  id: string;
  name: string;
  fileUri: string;
  filePath: string;
  sourceUri: string;

  constructor(
    id: string = '',
    name: string = '',
    fileUri: string = '',
    filePath: string = '',
    sourceUri: string = ''
  ) {
    this.id = id;
    this.name = name;
    this.fileUri = fileUri;
    this.filePath = filePath;
    this.sourceUri = sourceUri;
  }
}
