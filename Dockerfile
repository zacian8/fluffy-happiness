ARG IMAGE=ros:galactic
ARG RMF_WS=/opt/ros/rmf_ws

# multi-stage for caching
FROM $IMAGE AS cacher

# clone rmf source
ARG RMF_WS
WORKDIR $RMF_WS
RUN mkdir -p $RMF_WS/src && \
    git clone https://github.com/open-rmf/rmf.git && \
    vcs import src/ < rmf/rmf.repos

# copy manifests for caching
WORKDIR /opt
RUN mkdir -p /tmp/opt && \
    find ./ -name "package.xml" | xargs cp --parents -t /tmp/opt && \
    find ./ -name "COLCON_IGNORE" | xargs cp --parents -t /tmp/opt 2> /dev/null || :

# multi-stage for building
FROM $IMAGE AS builder

# install rmf dependencies
ARG RMF_WS
ARG DEBIAN_FRONTEND=noninteractive
WORKDIR $RMF_WS
COPY --from=cacher /tmp/$RMF_WS/src ./src
RUN . /opt/ros/$ROS_DISTRO/setup.sh && \
    rosdep update && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y python3-pip && \
    rosdep install -y --from-paths src --ignore-src && \
    rm -rf /var/lib/apt/lists/*

# build rmf source
COPY --from=cacher $RMF_WS/src ./src
RUN . /opt/ros/$ROS_DISTRO/setup.sh && \
    colcon build --symlink-install && \
    rm -rf log

# source entrypoint setup
ENV RMF_WS $RMF_WS
RUN sed --in-place --expression '$isource "$RMF_WS/install/setup.bash"' /ros_entrypoint.sh

CMD ["bash"]
