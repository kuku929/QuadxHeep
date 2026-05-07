# Mount the directory with the custom LLVM toolchain @ /tools/riscv_matrix_toolchain
# Mount the directory with Vivado @ /tools/vivado-{VIVADO_VERSION}
FROM ghcr.io/x-heep/x-heep/x-heep-toolchain:v1.0.5 AS xheep

WORKDIR /workspace/QuadxHeep/

ARG vivado_version=2025.2
ENV VIVADO_VERSION=${vivado_version}
ENV RISCV_XHEEP=/tools/riscv_matrix_toolchain
ENV TOOL_PATH=${RISCV_XHEEP}/bin:$TOOL_PATH:/tools/vivado-${VIVADO_VERSION}/${VIVADO_VERSION}/Vivado/bin

# Vivado specific stuff
RUN apt-get update && apt-get install -y libx11-6 libxext6 libxrender1 libxtst6 libxi6 libxrandr2 libxfixes3 libncurses5 libpixman-1-dev libpng16-16 locales;
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen;
RUN locale-gen;
RUN update-locale LANG=en_US.UTF-8;

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash", "-l"]

