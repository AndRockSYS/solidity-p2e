import hre from 'hardhat';
import { NumberGenerator, VRFCoordinator } from '../typechain-types';

export default async function deployVRFContracts(): Promise<[VRFCoordinator, NumberGenerator]> {
    const coordinator = await hre.ethers.deployContract('VRFCoordinator');
    await coordinator.createSubscription.send();
    await coordinator.fundSubscription.send(1, BigInt('1000000000000000000'));

    const numberGenerator = await hre.ethers.deployContract('NumberGenerator', [
        await coordinator.getAddress(),
        1,
        '0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc',
    ]);

    await coordinator.addConsumer.send(1, await numberGenerator.getAddress());

    return [coordinator, numberGenerator];
}
