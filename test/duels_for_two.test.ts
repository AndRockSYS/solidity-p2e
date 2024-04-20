import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { time, loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import deployVRFContracts from './deploy_vrf';
import { DuelsForTwo } from '../typechain-types';

const oneEther = BigInt('1000000000000000000');

describe('DuelsForTwo', () => {
    async function deployDuels(generatorAddress: string): Promise<DuelsForTwo> {
        return await hre.ethers.deployContract('DuelsForTwo', [10, generatorAddress]);
    }

    it('Should create new lobby', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);
        const duels = await deployDuels(await generator.getAddress());

        const [_owner, bluePlayer] = await ethers.getSigners();
        await duels
            .connect(bluePlayer)
            .createLobby(1, { value: oneEther, from: bluePlayer.address });

        const [blue, _red, _winner, pool, timestamp] = await duels.lobbies(0);

        expect(blue).to.be.equal(bluePlayer.address, 'Blue player has not entered');
        expect(pool).to.be.equal(oneEther, 'Pool is incorrect');
        expect(timestamp).to.be.equal(await time.latest(), 'Timestamp is incorrect');
    });

    it('Should be able to enter non-full duel and generate random number', async () => {
        const [coordinator, generator] = await loadFixture(deployVRFContracts);
        const duels = await deployDuels(await generator.getAddress());
        await generator.approve.send(await duels.getAddress(), true);

        const [_owner, bluePlayer, redPlayer, thirdPlayer] = await ethers.getSigners();

        await duels
            .connect(bluePlayer)
            .createLobby(1, { value: oneEther, from: bluePlayer.address });
        await duels.connect(redPlayer).enterLobby(0, { value: oneEther, from: redPlayer.address });

        await expect(
            duels.connect(thirdPlayer).enterLobby(0, { value: oneEther, from: thirdPlayer.address })
        ).to.be.revertedWith('Lobby is full');

        const requestId = await duels.requests(0);
        await coordinator.fulfillRandomWords(requestId, await generator.getAddress());
        const [isFullFilled, randomNumber] = await generator.getRequestStatus(requestId);

        expect(isFullFilled).to.be.equal(true, 'Request is not fullfilled');
        expect(randomNumber).to.be.not.equal(0n, 'Number is not assigned');
    });

    it('Should close non-full lobby after some time', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);
        const duels = await deployDuels(await generator.getAddress());

        const [_owner, bluePlayer] = await ethers.getSigners();
        await duels
            .connect(bluePlayer)
            .createLobby(1, { value: oneEther, from: bluePlayer.address });

        await expect(duels.connect(bluePlayer).closeLobbyAfterTime(0)).to.be.revertedWith(
            'Lobby cannot be closed now'
        );

        await time.increase(5 * 60 + 1);

        const balanceBefore = await ethers.provider.getBalance(await duels.getAddress());
        await duels.connect(bluePlayer).closeLobbyAfterTime(0);
        const balanceAfter = await ethers.provider.getBalance(await duels.getAddress());

        expect(balanceBefore - balanceAfter).to.be.equal(oneEther);
    });

    it('Should finish the game and choose a winner', async () => {
        const [_owner, bluePlayer, redPlayer] = await ethers.getSigners();

        const [coordinator, generator] = await loadFixture(deployVRFContracts);
        const duels = await deployDuels(await generator.getAddress());
        await generator.approve.send(await duels.getAddress(), true);

        await duels
            .connect(bluePlayer)
            .createLobby(1, { value: oneEther, from: bluePlayer.address });
        await duels.connect(redPlayer).enterLobby(0, { value: oneEther, from: redPlayer.address });

        await expect(
            duels.connect(bluePlayer).startLobby(0, { from: bluePlayer.address })
        ).to.be.revertedWith('The request was not fullfilled yet');

        const requestId = await duels.requests(0);
        await coordinator.fulfillRandomWords(requestId, await generator.getAddress());

        const [_isFullFilled, randomNumber] = await generator.getRequestStatus(requestId);
        const [blue, red, _winner, _pool, _timestamp] = await duels.lobbies(0);
        const winner = randomNumber % 2n == 0n ? blue : red;

        const winnerBalanceBefore = await ethers.provider.getBalance(winner);
        await duels.connect(bluePlayer).startLobby(0, { from: bluePlayer.address });
        const winnerBalanceAfter = await ethers.provider.getBalance(winner);

        expect(winner).to.be.equal(await duels.getLobbyWinner(0), 'Winner was not set');

        const commision = ((2n * oneEther) / 100n) * 10n;
        expect(winnerBalanceAfter - winnerBalanceBefore).to.be.equal(
            2n * oneEther - commision,
            'Winner did not get the reward'
        );

        const duelsBalanceAfter = await ethers.provider.getBalance(await duels.getAddress());
        expect(duelsBalanceAfter).to.be.equal(commision, 'Duel contract did not get commision');
    });
});
