import { expect } from 'chai';
import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import deployVRFContracts from './deploy_vrf';

describe('NumberGenerator', () => {
    it('Should allow only approved address to use the generator', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);

        const [_owner, randomUser] = await ethers.getSigners();

        await expect(
            generator.connect(randomUser).generateRandomNumber.send({ from: randomUser.address })
        ).to.be.revertedWith('You are not allowed to use generator');

        await generator.approve.send(randomUser.address, true);

        const requestId = await generator
            .connect(randomUser)
            .generateRandomNumber.send({ from: randomUser.address });
        expect(requestId).to.be.not.equal(0);
    });
});
