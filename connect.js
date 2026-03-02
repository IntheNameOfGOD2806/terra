import {
  createSshConnection,
  SshConnection,
  ConnectConfig
} from "ssh-remote-port-forward";


const connectConfig = {
  host: "example",
  port: "22",
};

const sshConnection = await createSshConnection(
  connectConfig
);

await sshConnection.remoteForward("localhost", 8000)